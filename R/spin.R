#' Spin goat's hair into wool
#'
#' This function takes a specially formatted R script and converts it to a
#' literate programming document. By default normal text (documentation) should
#' be written after the roxygen comment (\code{#'}) and code chunk options are
#' written after \code{#+} or \code{#-} or \code{# ----}.
#'
#' Obviously the goat's hair is the original R script, and the wool is the
#' literate programming document (ready to be knitted).
#' @param hair the path to the R script
#' @param knit logical: whether to compile the document after conversion
#' @param report logical: whether to generate report for \file{Rmd}, \file{Rnw}
#'   and \file{Rtex} output (ignored if \code{knit = FALSE})
#' @param text a character vector as an alternative way to \code{hair} to
#'   provide the R source; if \code{text} is not \code{NULL}, \code{hair} will
#'   be ignored
#' @param envir the environment for \code{\link{knit}()} to evaluate the code
#' @param format character: the output format (it takes five possible values);
#'   the default is R Markdown
#' @param doc a regular expression to identify the documentation lines; by
#'   default it follows the roxygen convention, but it can be customized, e.g.
#'   if you want to use \code{##} to denote documentation, you can use
#'   \code{'^##\\\\s*'}
#' @param inline a regular expression to identify inline R expressions; by
#'   default, code of the form \code{((code))} on its own line is treated as an
#'   inline expression
#' @param comment a pair of regular expressions for the start and end delimiters
#'   of comments; the lines between a start and an end delimiter will be
#'   ignored; by default, the delimiters are \verb{/*} in the beginning and
#'   \verb{*/} in the end of a line (following the convention of C comments)
#' @param precious logical: whether intermediate files (e.g., \code{.Rmd} files
#'   when \code{format} is \code{"Rmd"}) should be preserved; default
#'   \code{FALSE} if \code{knit == TRUE} and input is a file
#' @author Yihui Xie, with the original idea from Richard FitzJohn (who named it
#'   as \code{sowsear()} which meant to make a silk purse out of a sow's ear)
#' @return If \code{text} is \code{NULL}, the path of the final output document,
#'   otherwise the content of the output.
#' @note If the output format is Rnw and no document class is specified in
#'   roxygen comments, this function will automatically add the \code{article}
#'   class to the LaTeX document so that it is complete and can be compiled. You
#'   can always specify the document class and other LaTeX settings in roxygen
#'   comments manually.
#'
#'   When the output format is Rmd, it is compiled to HTML via
#'   \code{\link{knit2html}()}, which uses R Markdown v1 instead of v2. If you
#'   want to use the latter, you should call
#'   \code{rmarkdown::\link[rmarkdown]{render}()} instead.
#' @export
#' @seealso \code{\link{stitch}} (feed a template with an R script)
#' @references \url{https://yihui.name/knitr/demo/stitch/}
#' @examples #' write normal text like this and chunk options like below
#'
#' #+ label, opt=value
#'
#' # /*
#' #' these lines are treated as comments in spin()
#' 1+1
#' # */
#'
#' (s = system.file('examples', 'knitr-spin.R', package = 'knitr'))
#' spin(s)  # default markdown
#' o = spin(s, knit = FALSE) # convert only; do not make a purse yet
#' knit2html(o) # compile to HTML
#'
#' # other formats
#' spin(s, FALSE, format='Rnw')  # you need to write documentclass after #'
#' spin(s, FALSE, format='Rhtml')
#' spin(s, FALSE, format='Rtex')
#' spin(s, FALSE, format='Rrst')
spin = function(
  hair, knit = TRUE, report = TRUE, text = NULL, envir = parent.frame(),
  format = c('Rmd', 'Rnw', 'Rhtml', 'Rtex', 'Rrst'),
  doc = "^#+'[ ]?", inline = '^[{][{](.+)[}][}][ ]*$',
  comment = c("^[# ]*/[*]", "^.*[*]/ *$"), precious = !knit && is.null(text)
) {

  format = match.arg(format)
  x = if (nosrc <- is.null(text)) readLines(hair, warn = FALSE) else split_lines(text)
  stopifnot(length(comment) == 2L)
  c1 = grep(comment[1], x); c2 = grep(comment[2], x)
  if (length(c1) != length(c2))
    stop('comments must be put in pairs of start and end delimiters')
  # remove comments
  if (length(c1)) x = x[-unique(unlist(mapply(seq, c1, c2, SIMPLIFY = FALSE)))]

  p = .fmt.pat[[tolower(format)]]
  # turn ((expr)) into inline expressions, e.g. `r expr` or \Sexpr{expr}
  if (any(i <- grepl(inline, x))) x[i] = gsub(inline, p[4], x[i])

  r = rle(grepl(doc, x) | i)  # inline expressions are treated as doc instead of code
  n = length(r$lengths); txt = vector('list', n); idx = c(0L, cumsum(r$lengths))
  p1 = gsub('\\{', '\\\\{', paste0('^', p[1L], '.*', p[2L], '$'))

  for (i in seq_len(n)) {
    block = x[seq(idx[i] + 1L, idx[i + 1])]
    txt[[i]] = if (r$values[i]) {
      # normal text; just strip #'
      sub(doc, '', block)
    } else {
      # R code; #+/- indicates chunk options
      block = strip_white(block) # rm white lines in beginning and end
      if (!length(block)) next
      if (length(opt <- grep('^#+(\\+|-| ----+| @knitr)', block))) {
        block[opt] = paste0(p[1L], gsub('^#+(\\+|-| ----+| @knitr)\\s*|-*\\s*$', '', block[opt]), p[2L])
      }
      if (!grepl(p1, block[1L])) {
        block = c(paste0(p[1L], p[2L]), block)
      }
      c('', block, p[3L], '')
    }
  }

  txt = unlist(txt)
  # make it a complete TeX document if document class not specified
  if (report && format %in% c('Rnw', 'Rtex') && !grepl('^\\s*\\\\documentclass', txt)) {
    txt = c('\\documentclass{article}', '\\begin{document}', txt, '\\end{document}')
  }
  if (nosrc) {
    outsrc = sub_ext(hair, format)
    cat(txt, file = outsrc, sep = '\n')
    txt = NULL
  } else outsrc = NULL
  if (!knit) return(txt %n% outsrc)

  out = if (report) {
    if (format == 'Rmd') {
      knit2html(outsrc, text = txt, envir = envir)
    } else if (!is.null(outsrc) && (format %in% c('Rnw', 'Rtex'))) {
      knit2pdf(outsrc, envir = envir)
    }
  } else knit(outsrc, text = txt, envir = envir)

  if (!precious && !is.null(outsrc)) file.remove(outsrc)
  invisible(out)
}

.fmt.pat = list(
  rmd = c('```{r ', '}', '```', '`r \\1`'),
  rnw = c('<<', '>>=', '@', '\\\\Sexpr{\\1}'),
  rhtml = c('<!--begin.rcode ', '', 'end.rcode-->', '<!--rinline \\1 -->'),
  rtex = c('% begin.rcode ', '', '% end.rcode', '\\\\rinline{\\1}'),
  rrst = c('.. {r ', '}', '.. ..', ':r:`\\1`')
)

#' Spin a child R script
#'
#' This function is similar to \code{\link{knit_child}()} but is used in R
#' scripts instead. When the main R script is not called via
#' \code{\link{spin}()}, this function simply executes the child script via
#' \code{\link{sys.source}()}, otherwise it calls \code{\link{spin}()} to spin
#' the child script into a source document, and uses \code{\link{knit_child}()}
#' to compile it. You can call this function in R code, or using the syntax of
#' inline R expressions in \code{\link{spin}()} (e.g.
#' \code{{{knitr::spin_child('script.R')}}}).
#' @param input the filename of the input R script
#' @param format to be passed to \code{format} in \code{spin()}; if not
#'   provided, it will be guessed from the current knitting process
#' @return A character string of the knitted R script.
#' @export
spin_child = function(input, format) {
  if (!isTRUE(getOption('knitr.in.progress')))
    return(sys.source(input, parent.frame()))
  fmt = if (missing(format)) {
    if (is.null(fmt <- out_format()))
      stop('spin_child() must be called in a knitting process')
    .spin.fmt = c(
      'latex' = 'Rnw', 'sweave' = 'Rnw', 'listings' = 'Rnw',
      'html' = 'Rhtml', 'markdown' = 'Rmd'
    )
    if (is.na(fmt <- .spin.fmt[fmt]))
      stop('the document format ', fmt, ' is not supported yet')
    fmt
  } else format
  asis_output(knit_child(
    text = spin(text = readLines(input), knit = FALSE, report = FALSE, format = fmt),
    quiet = TRUE
  ))
}
