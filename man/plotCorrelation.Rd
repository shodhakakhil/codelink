\name{plotCorrelation}
\alias{plotCorrelation}
\title{Plot correlation scatterplot between two arrays}
\description{
	Takes a Codelink object as argument and plot Correlation scatterplot
	of two arrays.
}
\usage{
	plotCorrelation(object, x=1, y=2, cutoff=FALSE, label="type", title=NULL, xlim=NULL, ylim=NULL)
}
\arguments{
	\item{object}{an object of class "Codelink".}
	\item{x}{array to be used in x axis.}
	\item{y}{array to be used in y axis.}
	\item{cutoff}{cutoff used to show fold change.}
	\item{label}{labels to shown.}
	\item{title}{The title of the plot.}
        \item{xlim}{range for the X axis.}
        \item{ylim}{range for the Y axis.}
}
\author{Diego Diez}
\seealso{\code{\link{plot}}}
\examples{
\dontrun{
    data(codelink.example)
    plotCorrelation(codelink.example)
}
}
\keyword{documentation}
\keyword{utilities}
