% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data.processing.R
\name{classify_splicing_code}
\alias{classify_splicing_code}
\title{This function take the input of rMATS (http://rnaseq-mats.sourceforge.net/user_guide.htm#output)
or rMATS HM files and calssify alternative spliced exons into different
categories (splicing codes): gain (0), loss (1), High (2) and Low (3)}
\usage{
classify_splicing_code(SE_file)
}
\arguments{
\item{SE_file:}{rMAT result or rMAST result with HM signal at the end}
}
\value{
File with a class label indicates splicing codes
}
\description{
This function take the input of rMATS (http://rnaseq-mats.sourceforge.net/user_guide.htm#output)
or rMATS HM files and calssify alternative spliced exons into different
categories (splicing codes): gain (0), loss (1), High (2) and Low (3)
}
