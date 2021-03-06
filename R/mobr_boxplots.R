#' Calculate probability of interspecific encounter (PIE)
#' 
#' PIE is also known as Simpson's evenness index and this function is 
#' a reduced form of the function vegan::diversity(). Jari Oksanen and Bob O'Hara
#' are the original authors of the function vegan::diversity()
#' 
#' @inheritParams rarefaction
#' @author Dan McGlinn
#' @keywords internal
#' @examples 
#' data(inv_comm)
#' calc_PIE(inv_comm)
calc_PIE = function(x) {
    x = drop(as.matrix(x))
    if (any(x < 0, na.rm = TRUE)) 
        stop("input data must be non-negative")
    if (length(dim(x)) > 1) {
        total = apply(x, 1, sum)
        x = sweep(x, 1, total, "/")
    }
    else {
        total = sum(x)
        x = x / total
    }
    x = x * x
    if (length(dim(x)) > 1) 
        H = apply(x, 1, sum, na.rm = TRUE)
    else 
        H = sum(x, na.rm = TRUE)
        H = 1 - H
    if (any(is.na(total))) 
        is.na(H) = is.na(total)
    return(H)
}


#' Calculate sample based and group based biodiversity statistics
#' @inheritParams get_delta_stats
#' @param group_var a string that specifies which field in mob_in$env the data
#'   should be grouped by
#' @param n_min the minimum number of individuals a plot must have to be included
#' in the estimate of rarefied richness
#' @param nperm the number of permutations to use for testing for treatment effects
#' @return a list of class \code{mob_stats} that contains p-values,
#'  sample-scale (i.e., plot) statistics, and treatment scale statistics
#' @importFrom SpadeR ChaoSpecies
#' @author Felix May and Dan McGlinn
#' @export
#' @examples 
#' data(inv_comm)
#' data(inv_plot_attr)
#' inv_mob_in = make_mob_in(inv_comm, inv_plot_attr)
#' inv_stats = get_mob_stats(inv_mob_in, 'group', nperm=100)
#' plot(inv_stats, multipanel=TRUE)
get_mob_stats = function(mob_in, group_var, n_min = 10, nperm = 1000) {
   if (nperm < 1) 
       stop('Set nperm to a value greater than 1') 
   group_id  = factor(mob_in$env[, group_var])
   
   # Sample-based statistics
   N_sample = rowSums(mob_in$comm)      # individuals in each sample
   S_sample = rowSums(mob_in$comm > 0)  # species in each sample
   
   # rarefied richness
   N_min_sample = max(n_min, min(N_sample))
   plots_low_n = N_sample < n_min
   
   if (sum(plots_low_n) > 0){
      warning(paste("There are",sum(plots_low_n),"plots with less then", n_min,"individuals.
These are removed for the calculation of rarefied richness."))
   }

   S_rare_sample = rep(NA, nrow(mob_in$comm))
   S_rare_sample[!plots_low_n] = apply(mob_in$comm[!plots_low_n,], MARGIN = 1,
                                       FUN = rarefaction, method = "indiv",
                                       effort = N_min_sample)
   
   # Probability of Interspecific Encounter
   plots_n0 = N_sample == 0
   
   if (sum(plots_n0) > 0){
      warning(paste("There are",sum(plots_n0), "plots without any individuals.
These are removed for the calculation of PIE."))
   }
   
   PIE_sample = diversity(mob_in$comm, index = "simpson")
   ENS_PIE_sample = diversity(mob_in$comm, index = "invsimpson")
   PIE_sample[plots_n0] = NA
   ENS_PIE_sample[plots_n0] = NA
   
   # bias corrected Chao estimator
   S_asymp_sample = estimateR(mob_in$comm)["S.chao1",]
 
   # ---------------------------------------------------------------------------
   # abundance distribution pooled in group
   abund_group = aggregate(mob_in$comm, by = list(group_id), FUN = "sum")[ ,-1]
   
   # Group-based statistics
   N_group = rowSums(abund_group)      
   S_group = rowSums(abund_group > 0) 
   
   N_min_group = max(n_min, min(N_group))
   groups_low_n = N_group < n_min
   
   if (sum(groups_low_n) > 0){
      warning(paste("There are",sum(plots_low_n),"groups with less then", n_min,"individuals.
These are removed for the calculation of rarefied richness."))
   }
   
   S_rare_group = rep(NA, length(N_group))
   S_rare_group[!groups_low_n] = apply(abund_group[!groups_low_n], MARGIN = 1,
                                       FUN = rarefaction, method = "indiv",
                                       effort = N_min_group)
   
   # Probability of Interspecific Encounter
   groups_n0 = N_group == 0
   
   if (sum(groups_n0) > 0){
      warning(paste("There are",sum(groups_n0), "groups without any individuals.
                    These are removed for the calculation of PIE."))
   }
   
   PIE_group = diversity(abund_group, index = "simpson")
   ENS_PIE_group = diversity(abund_group, index = "invsimpson")
   PIE_group[groups_n0] = NA
   ENS_PIE_group[groups_n0] = NA
   
   # bias corrected Chao estimator
   S_asymp_group = estimateR(abund_group)["S.chao1",]
   
   #beta PIE
   betaPIE_sample = PIE_group[group_id] - PIE_sample
   
   # permutation test for differences among samples
   F_obs <- data.frame(S       = anova(lm(S_sample ~ group_id))$F[1],
                       N       = anova(lm(N_sample ~ group_id))$F[1],
                       S_rare  = anova(lm(S_rare_sample ~ group_id))$F[1],
                       PIE     = anova(lm(PIE_sample ~ group_id))$F[1],
                       ENS_PIE = anova(lm(ENS_PIE_sample ~ group_id))$F[1],
                       S_asymp = anova(lm(S_asymp_sample ~ group_id))$F[1],
                       betaPIE = anova(lm(betaPIE_sample ~ group_id))$F[1]
                      )
   
   F_rand <- data.frame(S       = numeric(nperm),
                        N       = numeric(nperm),
                        S_rare  = numeric(nperm),
                        PIE     = numeric(nperm),
                        ENS_PIE = numeric(nperm),
                        S_asymp = numeric(nperm),
                        betaPIE = numeric(nperm)
                        )
   
   for (i in 1:nperm){
      group_id_rand     = sample(group_id)
      F_rand$S[i]       = anova(lm(S_sample ~ group_id_rand))$F[1]
      F_rand$N[i]       = anova(lm(N_sample ~ group_id_rand))$F[1]
      F_rand$S_rare[i]  = anova(lm(S_rare_sample ~ group_id_rand))$F[1]
      F_rand$PIE[i]     = anova(lm(PIE_sample ~ group_id_rand))$F[1]
      F_rand$ENS_PIE[i] = anova(lm(ENS_PIE_sample ~ group_id_rand))$F[1]
      F_rand$S_asymp[i] = anova(lm(S_asymp_sample ~ group_id_rand))$F[1]
      F_rand$betaPIE[i] = anova(lm(betaPIE_sample ~ group_id_rand))$F[1]
   }
   
   p_S       = sum(F_obs$S       <= F_rand$S) / nperm
   p_N       = sum(F_obs$N       <= F_rand$N) / nperm
   p_S_rare  = sum(F_obs$S_rare  <= F_rand$S_rare) / nperm
   p_PIE     = sum(F_obs$PIE     <= F_rand$PIE) / nperm
   p_ENS_PIE = sum(F_obs$ENS_PIE <= F_rand$ENS_PIE) / nperm
   p_S_asymp = sum(F_obs$S_asymp <= F_rand$S_asymp) / nperm
   p_betaPIE = sum(F_obs$betaPIE <= F_rand$betaPIE) / nperm
   stats_pvalues = data.frame(S       = p_S,
                              N       = p_N,
                              S_rare  = p_S_rare,
                              ENS_PIE = p_ENS_PIE,
                              S_asymp = p_S_asymp,
                              betaPIE = p_betaPIE)

   stats_samples = data.frame(group   = group_id,
                              N       = N_sample,
                              S       = S_sample,
                              S_rare  = S_rare_sample,
                              S_asymp = S_asymp_sample,
                              PIE     = PIE_sample,
                              ENS_PIE = ENS_PIE_sample,
                              betaPIE = betaPIE_sample
                              )
   
   stats_groups = data.frame(group  = factor(levels(group_id), ordered = is.ordered(group_id)),
                             N      = N_group,
                             S      = S_group,
                             S_rare = S_rare_group,
                             S_asymp = S_asymp_group,
                             PIE    = PIE_group,
                             ENS_PIE = ENS_PIE_group
                             )
   out = list(pvalues = stats_pvalues,
              samples = stats_samples,
              groups  = stats_groups)
   class(out) = 'mob_stats'
   return(out)
   
}

#' Plot the scale agnostic statistics for a MoB analysis
#' 
#' Plots a \code{mob_stats} object which is produced by the 
#' function \code{get_mob_stats}. The p value for each statistic
#' is displayed in the plot title if applicable.
#' 
#' The user may specify which results to plot or simply to plot 
#' all the results. Note however that the rarefied species richness
#' results are not plotted by all
#' @param mob_stats a \code{mob_stats} object that has the samples and 
#' treatment level statistics
#' @param display eith a single character value of a vector of character
#' values. If set to \code{all} then plots of PIE, beta PIE, S, N, and asymptic
#' S will be produced, but not a plot of rarefied S. 
#' @param multipanel a boolean if TRUE then a pretty multipanel plot is produced 
#' setting this argument to TRUE only makes sense when displaying all the 
#' results (i.e., \code{display = 'all'})
#' @param ... additional graphical arguments to be supplied to the boxplot and
#' points functions
#' @author Felix May and Dan McGlinn 
#' @export
#' @examples 
#' data(inv_comm)
#' data(inv_plot_attr)
#' inv_mob_in = make_mob_in(inv_comm, inv_plot_attr)
#' inv_stats = get_mob_stats(inv_mob_in, 'group', nperm=100)
#' plot(inv_stats, multipanel=TRUE)
#' # with colors
#' plot(inv_stats, multipanel=TRUE, col=c('red', 'blue'))
#' # only display PIE results
#' par(mfrow=c(1,3))
#' plot(inv_stats, 'PIE', col=c('red', 'blue'))
plot.mob_stats = function(mob_stats, 
                          display=c('all', 'PIE', 'beta PIE',
                                    'N', 'S', 'S rare', 'S asymp'),
                          multipanel=FALSE, ...) {
      if (multipanel) {
          if ('all' %in% display) {
              display = c('PIE', 'N', 'S', 'S asymp')
              op = par(mfcol = c(3,5), las = 1, font.main = 1,
                       mar = c(2, 2, 3, 2) + 0.1)
          }
          else
              warning('The multipanel plots settings only make sense when display is set to "all"')
      } else if ('all' %in% display)
          display = c('PIE', 'N', 'S', 'S asymp')
      # PIE
      if ('PIE' %in% display) {
          if (multipanel)
              par(fig = c(0.2, 0.4, 0.66, 1))
          panel_title = paste("PIE (p = ", mob_stats$pvalues$ENS_PIE,")\nplot scale",
                              sep = "")
          boxplot(PIE ~ group, data=mob_stats$samples,
                  main = panel_title, ...)
          if (multipanel)
              par(fig = c(0.4, 0.6, 0.66, 1), new = T)
          panel_title = paste("beta PIE (p = ", mob_stats$pvalues$betaPIE,")\nbetween scales",
                              sep = "")
          boxplot(betaPIE ~ group, data=mob_stats$samples,
                  main = panel_title, ...)
          if (multipanel)
              par(fig = c(0.6, 0.8, 0.66, 1), new = T)
          boxplot(PIE ~ levels(group), data=mob_stats$groups,
                  main = "PIE\ntreatment scale", boxwex = 0)
          points(mob_stats$groups$PIE, pch = 19, ...)
      }
      if ('S' %in% display) {
          if (multipanel)
              par(fig = c(0, 0.2, 0.33, 0.66), new = T)

          # S observed samples
          panel_title = paste("S (p = ", mob_stats$pvalues$S,")\n plot scale",
                              sep = "")
          boxplot(S ~ group, data=mob_stats$samples,
                  main = panel_title, ...)
          
          # S groups
          if (multipanel)
              par(fig = c(0.8, 1.0, 0.33, 0.66), new = T)
          boxplot(S ~ levels(group), data=mob_stats$groups,
                  main = "S\ntreatment scale", boxwex = 0)
          points(mob_stats$groups$S, pch = 19, ...)

      }
      if ('S rare' %in% display) {
          if (multipanel)
              par(fig = c(0, 0.2, 0.33, 0.66), new = T)

          # S rareified samples
          panel_title = paste("S rarefied (p = ", mob_stats$pvalues$S_rare,
                              ")\n plot scale", sep = "")
          boxplot(S_rare ~ group, data=mob_stats$samples,
                  main = panel_title, ...)
          
          # S groups
          if (multipanel)
              par(fig = c(0.8, 1.0, 0.33, 0.66), new = T)
          boxplot(S_rare ~ levels(group), data=mob_stats$groups,
                  main = "S rarefied\ntreatment scale", boxwex = 0)
          points(mob_stats$groups$S_rare, pch = 19, ...)

      }
      if ('N' %in% display) {
          if (multipanel)
              par(fig = c(0.2, 0.4, 0.33, 0.66), new = T)
          # N samples
          panel_title = paste("N (p = ", mob_stats$pvalues$N,")\n plot scale",
                              sep = "")
          boxplot(N ~ group, data=mob_stats$samples, 
                  main = panel_title, ...)
      
          # N groups
          if (multipanel)
              par(fig = c(0.6, 0.8, 0.33, 0.66), new = T)
          boxplot(N ~ levels(group), data=mob_stats$groups,
                  main = "N\ntreatment scale", boxwex = 0)
          points(mob_stats$groups$N, pch = 19, ...)
      }
      if ('S asymp' %in% display) {
          if (multipanel)
              par(fig = c(0.2, 0.4, 0, 0.33), new = T)
          # S asymptotic
          panel_title = paste("S asympotic (p = ", mob_stats$pvalues$S_asymp,
                              ")\n plot scale", sep = "")
          boxplot(S_asymp ~ group, data=mob_stats$samples,
                  main = panel_title, ...)
          
          if (multipanel)
              par(fig = c(0.6, 0.8, 0, 0.33), new = T)
          boxplot(S_asymp ~ levels(group), data=mob_stats$groups,
                  main = "S asympotic\ntreatment scale", boxwex = 0)
          points(mob_stats$groups$S_asymp, pch = 19, ...)
      }
      if (multipanel)
          par(op)
}


#' Additional plotting function for betaPIE statistics 
#' @inheritParams plot.mob_stats
#' @author Felix May and Dan McGlinn
#' @export
#' @examples 
#' data(inv_comm)
#' data(inv_plot_attr)
#' inv_mob_in = make_mob_in(inv_comm, inv_plot_attr)
#' inv_stats = get_mob_stats(inv_mob_in, 'group', nperm=100)
#' plot_betaPIE(inv_stats)
plot_betaPIE = function(mob_stats)
{
   ngroups = nrow(mob_stats$groups)
   
   op = par(mfrow = c(1,2), las = 1, font.main = 1)
   pie_range = range(c(mob_stats$samples$PIE, mob_stats$groups$PIE),
                     na.rm=T)
   boxplot(PIE ~ group, data = mob_stats$sample, ylim = pie_range, ylab = "PIE",
           notch = T, main = "Sample and group PIE")
   points((1:ngroups)+0.1, mob_stats$groups$PIE, pch = 23, bg = "grey", cex = 1.5)
   
   boxplot(betaPIE ~ group, data = mob_stats$samples,
           ylab = " betaPIE", notch = T, main = "Group PIE - sample PIE")
   par(op)
}
