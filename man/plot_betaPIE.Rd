% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mobr_boxplots.R
\name{plot_betaPIE}
\alias{plot_betaPIE}
\title{Additional plotting function for betaPIE statistics}
\usage{
plot_betaPIE(mob_stats)
}
\arguments{
\item{mob_stats}{a \code{mob_stats} object that has the samples and 
treatment level statistics}
}
\description{
Additional plotting function for betaPIE statistics
}
\examples{
data(inv_comm)
data(inv_plot_attr)
inv_mob_in = make_mob_in(inv_comm, inv_plot_attr)
inv_stats = get_mob_stats(inv_mob_in, 'group', nperm=100)
plot_betaPIE(inv_stats)
}
\author{
Felix May and Dan McGlinn
}

