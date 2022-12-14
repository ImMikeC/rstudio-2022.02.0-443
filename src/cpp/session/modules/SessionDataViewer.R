#
# SessionDataViewer.R
#
# Copyright (C) 2022 by RStudio, PBC
#
# Unless you have received this program directly from RStudio pursuant
# to the terms of a commercial license agreement with RStudio, then
# this program is licensed to you under the terms of version 3 of the
# GNU Affero General Public License. This program is distributed WITHOUT
# ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
# AGPL (http://www.gnu.org/licenses/agpl-3.0.txt) for more details.
#
#

# host environment for cached data; this allows us to continue to view data 
# even if the original object is deleted
.rs.setVar("CachedDataEnv", new.env(parent = emptyenv()))

# host environment for working data; this allows us to sort/filter/page the
# data without recomputing on the original object every time
.rs.setVar("WorkingDataEnv", new.env(parent = emptyenv()))

.rs.addFunction("formatDataColumn", function(x, start, len, ...)
{
   # extract the visible part of the column
   col <- x[start:min(NROW(x), start + len)]
   
   # if this object has a format method, use it. catch errors
   # and validate that the format method has given us something 'sane'
   formatted <- .rs.tryCatch(.rs.formatDataColumnDispatch(col, ...))
   if (is.character(formatted) && length(formatted) == length(col))
      return(formatted)
   
   # otherwise, delegate to internal methods
   if (is.numeric(col))
      .rs.formatDataColumnNumeric(col, ...)
   else
      .rs.formatDataColumnDefault(col, ...)
})

.rs.addFunction("formatDataColumnDispatch", function(col, ...)
{
   formatter <- utils::getS3method(
      "format",
      class = class(col),
      optional = TRUE
   )
   
   if (is.null(formatter))
      return(NULL)
   
   formatted <- formatter(col, trim = TRUE, justify = "none", ...)
   
   if (is.character(formatted) && length(formatted) == length(col))
      formatted[is.na(col)] <- NA
   
   formatted
   
})

.rs.addFunction("formatDataColumnNumeric", function(col, ...)
{
   # show numbers as doubles
   storage.mode(col) <- "double"
   
   # remember which values are NA 
   naVals <- is.na(col) 
   
   # format all the numeric values; this drops NAs (the na.encode option only
   # preserves NA for character cols)
   vals <- format(col, trim = TRUE, justify = "none", ...)
   
   # restore NA values if there were any
   if (any(naVals))
      vals[naVals] <- col[naVals]
   
   # return formatted values
   vals
})

.rs.addFunction("formatDataColumnDefault", function(col, ...)
{
   # show everything else as characters
   as.character(col)
})

.rs.addFunction("describeCols", function(x, maxFactors) 
{
   colNames <- names(x)
   
   # get the variable labels, if any--labels may be provided either by this 
   # global attribute or by a 'label' attribute on an individual column (as in
   # e.g. Hmisc), which takes precedence if both are present
   colLabels <- attr(x, "variable.labels", exact = TRUE)
   if (!is.character(colLabels)) 
   {
      colLabels <- character()
   }
   
   # the first column is always the row names
   rowNameCol <- list(
      col_name        = .rs.scalar(""),
      col_type        = .rs.scalar("rownames"),
      col_min         = .rs.scalar(0),
      col_max         = .rs.scalar(0),
      col_search_type = .rs.scalar("none"),
      col_label       = .rs.scalar(""),
      col_vals        = "",
      col_type_r      = .rs.scalar(""))
   
   # if there are no columns, bail out
   if (length(colNames) == 0) {
      return(rowNameCol)
   }
   
   # get the attributes for each column
   colAttrs <- lapply(seq_along(colNames), function(idx) {
      col_name <- if (idx <= length(colNames)) 
         colNames[idx] 
      else 
         as.character(idx)
      col_type <- "unknown"
      col_type_r <- "unknown"
      col_breaks <- c()
      col_counts <- c()
      col_vals <- ""
      col_search_type <- ""
      
      # extract label, if any, or use global label, if any
      label <- attr(x[[idx]], "label", exact = TRUE)
      col_label <- if (is.character(label))
      {
         label
      }
      else if (idx <= length(colLabels))
      {
         if (col_name %in% names(colLabels))
            colLabels[[col_name]]
         else
            colLabels[[idx]]
      }
      else
      {
         ""
      }
      
      # ensure that the column contains some scalar values we can examine 
      if (length(x[[idx]]) > 0)
      {
         val <- x[[idx]][[1]]
         col_type_r <- typeof(val)
         if (is.factor(val))
         {
            col_type <- "factor"
            if (length(levels(val)) > maxFactors)
            {
               # if the number of factors exceeds the max, search the column as 
               # though it were a character column
               col_search_type <- "character"
            }
            else 
            {
               col_search_type <- "factor"
               col_vals <- levels(val)
            }
         }
         # for histograms, we support only the base R numeric class and its derivatives;
         # is.numeric can return true for values that can only be manipulated using
         # packages that are currently loaded (e.g. bit64's integer64)
         else if (is.numeric(x[[idx]]) && !is.object(x[[idx]]))
         {
            # ignore missing and infinite values (i.e. let any filter applied
            # implicitly remove those values); if that leaves us with nothing,
            # treat this column as untyped since we can do no meaningful filtering
            # on it
            hist_vals <- x[[idx]][is.finite(x[[idx]])]
            if (length(hist_vals) > 1)
            {
               # create histogram for brushing -- suppress warnings as in rare cases
               # an otherwise benign integer overflow can occurs; see
               # https://github.com/rstudio/rstudio/issues/3232
               h <- suppressWarnings(graphics::hist(hist_vals, plot = FALSE))
               col_breaks <- h$breaks
               col_counts <- h$counts
               
               # record column type
               col_type <- "numeric"
               col_search_type <- "numeric"
            }
         }
         else if (inherits(x[[idx]], "integer64"))
         {
            col_type <- "numeric"
            col_search_type <- "character"
         }
         else if (is.character(val))
         {
            col_type <- "character"
            col_search_type <- "character"
         }
         else if (is.logical(val))
         {
            col_type <- "boolean"
            col_search_type <- "boolean"
         }
         else if (is.data.frame(val))
         {
            col_type <- "data.frame"
         }
         else if (is.list(val))
         {
            col_type <- "list"
         }
      }
      list(
         col_name        = .rs.scalar(col_name),
         col_type        = .rs.scalar(col_type),
         col_breaks      = as.character(col_breaks),
         col_counts      = col_counts,
         col_search_type = .rs.scalar(col_search_type),
         col_label       = .rs.scalar(col_label),
         col_vals        = col_vals,
         col_type_r      = .rs.scalar(col_type_r)
      )
   })
   c(list(rowNameCol), colAttrs)
})

.rs.addFunction("formatRowNames", function(x, start, len) 
{
   # detect whether this is a data.frame that contains
   # row names, or if the row names are stored compactly
   if (is.data.frame(x))
   {
      info <- .row_names_info(x, type = 0L)
      if (is.integer(info) && length(info) > 0 && is.na(info[[1]]))
      {
         # the second element indicates the number of rows, and is negative if they're 
         # automatic
         n <- abs(info[[2]])
         range <- seq(from = start, to = min(n, start + len))
         return(as.character(range))
      }
   }
   
   # otherwise, extract row names and subset as usual
   rownames <- row.names(x)
   rownames[start:min(length(rownames), start + len)]
})

# wrappers for nrow/ncol which will report the class of object for which we
# fail to get dimensions along with the original error
.rs.addFunction("nrow", function(x)
{
   rows <- 0
   tryCatch({
      rows <- NROW(x)
   }, error = function(e) {
      stop("Failed to determine rows for object of class '", class(x), "': ", 
           e$message)
   })
   if (is.null(rows))
      0
   else
      rows
})

.rs.addFunction("ncol", function(x)
{
   cols <- 0
   tryCatch({
      cols <- NCOL(x)
   }, error = function(e) {
      stop("Failed to determine columns for object of class '", class(x), "': ", 
           e$message)
   })
   if (is.null(cols))
      0
   else
      cols
})

.rs.addFunction("toDataFrame", function(x, name, flatten) {
   
   # if we have a data.table, convert it to a data.frame explicitly
   if (inherits(x, "data.table"))
      x <- as.data.frame(x)
   
   # if it's not already a frame, coerce it to a frame
   if (!is.data.frame(x)) {
      frame <- NULL
      # attempt to coerce to a data frame--this can throw errors in the case
      # where we're watching a named object in an environment and the user
      # replaces an object that can be coerced to a data frame with one that
      # cannot
      tryCatch(
         {
            # create a temporary frame to hold the value; this is necessary because
            # "x" is a function argument and therefore a promise whose value won't
            # be bound via substitute() below. we use a random-looking name so we 
            # can spot it later when relabeling columns.
            `__RSTUDIO_VIEWER_COLUMN__` <- x
            
            # perform the actual coercion in the global environment; this is 
            # necessary because we want to honor as.data.frame overrides of packages
            # which are loaded after tools:rstudio in the search path
            frame <- eval(substitute(as.data.frame(`__RSTUDIO_VIEWER_COLUMN__`, 
                                                   optional = TRUE)), 
                          envir = globalenv())
         },
         error = function(e)
         {
         })
      
      # as.data.frame uses the name of its argument to label unlabeled columns,
      # so label these back to the original name
      if (!is.null(frame) && !is.null(names(frame)))
         names(frame)[names(frame) == "__RSTUDIO_VIEWER_COLUMN__"] <- name
      x <- frame 
   }
   
   # if coercion was successful (or we started with a frame), flatten the frame
   # if necessary and requested
   if (is.data.frame(x)) {
      
      # generate column names if we didn't have any to start
      if (is.null(names(x)))
         names(x) <- paste("V", seq_along(x), sep = "")
      
      if (flatten) {
         x <- .rs.flattenFrame(x)
      } 
      return(x)
   }
})

.rs.addFunction("multiCols", function(x) {
   fun <- function(col) is.data.frame(col) || is.matrix(col)
   which(vapply(x, fun, TRUE))
})

.rs.addFunction("flattenFrame", function(x) {
  multicols <- .rs.multiCols(x)
  while (length(multicols) > 0) {
    multicol <- multicols[1]
    newcols <- ncol(x[[multicol]])
    if (identical(newcols, 0)) 
    {
      # remove columns consisting of empty frames
      x[[multicol]] <- NULL
    }
    else
    {
      cols <- x[[multicol]]

      # recurse because x[[multicol]] might also need flattening
      if (length(.rs.multiCols(cols)) > 0L) {
        cols <- x[[multicol]] <- .rs.flattenFrame(cols)
        
        # readjust indices
        newcols <- ncol(cols)
      }
      
      # apply column names
      prefix <- names(multicol)[[1]]
      if (is.matrix(cols)) {
        colnames <- colnames(cols)
        if (is.null(colnames)) {
          colnames(cols) <- paste0(prefix, '[,', 1:ncol(cols), ']')
        } else {
          colnames(cols) <- paste0(prefix, '[,"', colnames, '"]')
        }

      } else if (is.data.frame(cols)) {
        names(cols) <- paste(prefix, names(cols), sep = "$")
      }
      
      # replace other columns in place
      if (multicol >= ncol(x))  {
        x <- cbind(x[0:(multicol-1)], cols)
      } else {
        x <- cbind(x[0:(multicol-1)], cols, x[(multicol+1):ncol(x)])
      }
    }
    
    # pop this frame off the list and adjust the other indices to account for
    # the columns we just added, if any
    multicols <- multicols[-1] + (max(newcols, 1) - 1) 
  }
  x
})

.rs.addFunction("applyTransform", function(x, filtered, search, cols, dirs)
{
   # mark encoding on character inputs if not already marked
   filtered <- vapply(filtered, function(colfilter) {
      if (Encoding(colfilter) == "unknown") 
         Encoding(colfilter) <- "UTF-8"
      colfilter
   }, "")
   if (Encoding(search) == "unknown")
      Encoding(search) <- "UTF-8"
   
   # coerce argument to data frame--data.table objects (for example) report that
   # they're data frames, but don't actually support the subsetting operations
   # needed for search/sort/filter without an explicit cast
   x <- .rs.toDataFrame(x, "transformed", TRUE)
   
   # apply columnwise filters
   for (i in seq_along(filtered)) {
      if (nchar(filtered[i]) > 0 && length(x[[i]]) > 0) {
         # split filter--string format is "type|value" (e.g. "numeric|12-25") 
         filter <- strsplit(filtered[i], split="|", fixed = TRUE)[[1]]
         if (length(filter) < 2) 
         {
            # no filter type information
            next
         }
         filtertype <- filter[1]
         filterval <- filter[2]
         
         # apply filter appropriate to type
         if (identical(filtertype, "factor")) 
         {
            # apply factor filter: convert to numeric values and discard missing
            filterval <- as.numeric(filterval)
            matches <- as.numeric(x[[i]]) == filterval
            matches[is.na(matches)] <- FALSE
            x <- x[matches, , drop = FALSE]
         }
         else if (identical(filtertype, "character"))
         {
            # apply character filter: non-case-sensitive prefix
            # use PCRE and the special \Q and \E escapes to ensure no characters in
            # the search expression are interpreted as regexes 
            x <- x[grepl(paste("\\Q", filterval, "\\E", sep = ""), x[[i]], 
                         perl = TRUE, ignore.case = TRUE), , 
                   drop = FALSE]
         } 
         else if (identical(filtertype, "numeric"))
         {
            # apply numeric filter, range ("2-32") or equality ("15")
            filterval <- as.numeric(strsplit(filterval, "_")[[1]])
            if (length(filterval) > 1)
               # range filter
               x <- x[is.finite(x[[i]]) & x[[i]] >= filterval[1] & x[[i]] <= filterval[2], , drop = FALSE]
            else
               # equality filter
               x <- x[is.finite(x[[i]]) & x[[i]] == filterval, , drop = FALSE]
         }
         else if (identical(filtertype, "boolean")) 
         {
            filterval <- isTRUE(filterval == "TRUE")
            matches <- x[[i]] == filterval
            matches[is.na(matches)] <- FALSE
            x <- x[matches, , drop = FALSE]
         }
      }
   }
   
   # apply global search
   if (!is.null(search) && nchar(search) > 0)
   {
      x <- x[Reduce("|", lapply(x, function(column) { 
         grepl(paste("\\Q", search, "\\E", sep = ""), column, perl = TRUE,
               ignore.case = TRUE)
      })), , drop = FALSE]
   }
   
   # apply sort
   if (length(cols) > 0)
   {
      vals <- list()
      for (i in length(cols))
      {
         idx <- cols[[i]]
         if (length(x[[idx]]) > 0)
         {
            if (identical(dirs[[i]], "asc"))
            {
               vals <- append(vals, list(x[[idx]]))
            }
            else
            {
               vals <- append(vals, list(-xtfrm(x[[idx]])))
            }
         }
      }
      
      if (length(vals) > 0)
      {
         x <- x[do.call(order, vals), , drop = FALSE]
      }
   }
   
   return(x)
})

# returns envName as an environment, or NULL if the conversion failed
.rs.addFunction("safeAsEnvironment", function(envName)
{
   env <- NULL
   tryCatch(
      {
         env <- as.environment(envName)
      }, 
      error = function(e) { })
   env
})

.rs.addFunction("findDataFrame", function(envName, objName, cacheKey, cacheDir) 
{
   env <- NULL
   
   # mark encoding on cache directory 
   if (Encoding(cacheDir) == "unknown")
      Encoding(cacheDir) <- "UTF-8"
   
   # do we have an object name? if so, check in a named environment
   if (!is.null(objName) && nchar(objName) > 0) 
   {
      if (is.null(envName) || identical(envName, "R_GlobalEnv") || 
          nchar(envName) == 0)
      {
         # global environment
         env <- globalenv()
      }
      else 
      {
         env <- .rs.safeAsEnvironment(envName)
         if (is.null(env))
            env <- emptyenv()
      }
      
      # if the object exists in this environment, return it (avoid creating a
      # temporary here)
      if (exists(objName, where = env, inherits = FALSE))
      {
         # attempt to coerce the object to a data frame--note that a null return
         # value here may indicate that the object exists in the environment but
         # is no longer a data frame (we want to fall back on the cache in this
         # case)
         dataFrame <- .rs.toDataFrame(get(objName, envir = env, inherits = FALSE), 
                                      objName, TRUE)
         if (!is.null(dataFrame)) 
            return(dataFrame)
      }
   }
   
   # if the object exists in the cache environment, return it. Objects
   # in the cache environment have already been coerced to data frames.
   if (exists(cacheKey, where = .rs.CachedDataEnv, inherits = FALSE))
      return(get(cacheKey, envir = .rs.CachedDataEnv, inherits = FALSE))
   
   # perhaps the object has been saved? attempt to load it into the
   # cached environment
   cacheFile <- file.path(cacheDir, paste(cacheKey, "Rdata", sep = "."))
   if (file.exists(cacheFile))
   {
      status <- try(load(cacheFile, envir = .rs.CachedDataEnv), silent = TRUE)
      if (inherits(status, "try-error"))
         return(NULL)
      
      if (exists(cacheKey, where = .rs.CachedDataEnv, inherits = FALSE))
         return(get(cacheKey, envir = .rs.CachedDataEnv, inherits = FALSE))
   }
   
   # failure
   return(NULL)
})

# given a name, return the first environment on the search list that contains
# an object bearing that name. 
.rs.addFunction("findViewingEnv", function(name)
{
   # default to searching from the global environment
   env <- globalenv()
   
   # attempt to find a callframe from which View was invoked; this will allow
   # us to locate viewing environments further in the callstack (e.g. in the
   # debugger)
   for (i in seq_along(sys.calls()))
   {
      if (identical(deparse(sys.call(i)[[1]]), "View"))
      {
         env <- sys.frame(i - 1)
         break
      }
   }
   
   while (environmentName(env) != "R_EmptyEnv" && 
          !exists(name, where = env, inherits = FALSE)) 
   {
      env <- parent.env(env)
   }
   env
})

# attempts to determine whether the View(...) function the user has an 
# override (i.e. it's not the handler RStudio uses)
.rs.addFunction("isViewOverride", function() {
   # check to see if View has been overridden: find the View() call in the 
   # stack and examine the function being evaluated there
   for (i in seq_along(sys.calls()))
   {
      if (identical(deparse(sys.call(i)[[1]]), "View"))
      {
         # the first statement in the override function should be a call to 
         # .rs.callAs
         return(!identical(deparse(body(sys.function(i))[[1]]), ".rs.callAs"))
      }
   }
   # if we can't find View on the callstack, presume the common case (no
   # override)
   FALSE
})

.rs.addFunction("viewHook", function(original, x, title) {
   
   # remember the expression from which the data was generated
   expr <- deparse(substitute(x), backtick = TRUE)
   
   # generate title if necessary (from deparsed expr)
   if (missing(title))
      title <- paste(expr[1])
   
   # collapse expr for serialization
   expr <- paste(expr, collapse = " ")
   
   name <- ""
   env <- emptyenv()
   
   
   if (.rs.isViewOverride()) 
   {
      # if the View() invoked wasn't our own, we have no way of knowing what's
      # been done to the data since the user invoked View() on it, so just view
      # a snapshot of the data
      name <- title
   }
   else if (is.name(substitute(x)))
   {
      # if the argument is the name of a variable, we can monitor it in its
      # environment, and don't need to make a copy for viewing
      name <- paste(deparse(substitute(x)))
      env <- .rs.findViewingEnv(name)
   }
   
   # is this a function? if it is, view as a function instead
   if (is.function(x)) 
   {
      # check the source refs to see if we can open the file itself instead of
      # opening a read-only source viewer
      srcref <- .rs.getSrcref(x)
      if (!is.null(srcref))
      {
         srcfile <- attr(srcref, "srcfile", exact = TRUE)
         filename <- .rs.nullCoalesce(srcfile$filename, "")
         if (!identical(filename, "~/.active-rstudio-document") &&
             file.exists(filename))
         {
            # the srcref points to a valid file--go there 
            .Call("rs_jumpToFunction",
                  normalizePath(filename, winslash = "/"),
                  srcref[[1]],
                  srcref[[5]],
                  TRUE,
                  PACKAGE = "(embedding)")
            
            return(invisible(NULL))
         }
      }
      
      # either this function doesn't have a source reference or its source
      # reference points to a file we can't locate on disk--show a deparsed
      # version of the function
      
      # remove package qualifiers from function name
      title <- sub("^[^:]+:::?", "", title)
      
      # infer environment location
      namespace <- .rs.environmentName(environment(x))
      if (identical(namespace, "R_EmptyEnv") || identical(namespace, ""))
         namespace <- "viewing"
      else if (identical(namespace, "R_GlobalEnv"))
         namespace <- ".GlobalEnv"
      invisible(.Call("rs_viewFunction", x, title, namespace, PACKAGE = "(embedding)"))
      return(invisible(NULL))
   }
   else if (inherits(x, "vignette"))
   {
      file.edit(file.path(x$Dir, "doc", x$File))
      return(invisible(NULL))
   }
   
   # delegate to object explorer if this is an 'explorable' object
   if (.rs.dataViewer.shouldUseObjectExplorer(x))
   {
      view <- .rs.explorer.viewObject(x, title = title, envir = env)
      return(invisible(view))
   }
   
   # convert Pandas DataFrames to R data.frames
   if (inherits(x, "pandas.core.frame.DataFrame"))
      x <- reticulate::py_to_r(x)
   
   # test for coercion to data frame--the goal of this expression is just to
   # raise an error early if the object can't be made into a frame; don't
   # require that we can generate row/col names
   coerced <- x
   eval(
      expr = substitute(as.data.frame(coerced, optional = TRUE)),
      envir = globalenv()
   )
   
   # save a copy into the cached environment
   cacheKey <- .rs.addCachedData(force(x), name)
   
   # call viewData 
   invisible(.Call("rs_viewData", x, expr, title, name, env, cacheKey, FALSE))
})

.rs.registerReplaceHook("View", "utils", .rs.viewHook)

.rs.addFunction("dataViewer.shouldUseObjectExplorer", function(object)
{
   # prefer data viewer for pandas DataFrames
   if (inherits(object, "pandas.core.frame.DataFrame"))
      return(FALSE)
   
   # don't explore regular data.frames
   isTabular <-
      is.data.frame(object) ||
      is.matrix(object) ||
      is.table(object)
   
   if (isTabular)
      return(FALSE)
   
   # other objects are worth using object explorer for
   TRUE
})

.rs.addFunction("viewDataFrame", function(x, title, preview) {
   cacheKey <- .rs.addCachedData(force(x), "")
   invisible(.Call("rs_viewData", x, "", title, "", emptyenv(), cacheKey, preview))
})

.rs.addFunction("initializeDataViewer", function(server) {
   if (server) {
      .rs.registerReplaceHook("edit", "utils", function(original, name, ...) {
         if (is.data.frame(name) || is.matrix(name))
            stop("Editing of data frames and matrixes is not supported in RStudio.", call. = FALSE)
         else
            original(name, ...)
      })
   }
})

.rs.addFunction("addCachedData", function(obj, objName) 
{
   cacheKey <- .Call("rs_generateShortUuid")
   .rs.assignCachedData(cacheKey, obj, objName)
   cacheKey
})

.rs.addFunction("assignCachedData", function(cacheKey, obj, objName) 
{
   # coerce to data frame before assigning, and don't assign if we can't coerce
   frame <- .rs.toDataFrame(obj, objName, TRUE)
   if (!is.null(frame))
      assign(cacheKey, frame, .rs.CachedDataEnv)
})

.rs.addFunction("removeCachedData", function(cacheKey, cacheDir)
{
   # mark encoding on cache directory 
   if (Encoding(cacheDir) == "unknown")
      Encoding(cacheDir) <- "UTF-8"
   
   # remove data from the cache environment
   if (exists(".rs.CachedDataEnv") &&
       exists(cacheKey, where = .rs.CachedDataEnv, inherits = FALSE))
      rm(list = cacheKey, envir = .rs.CachedDataEnv, inherits = FALSE)
   
   # remove data from the cache directory
   cacheFile <- file.path(cacheDir, paste(cacheKey, "Rdata", sep = "."))
   if (file.exists(cacheFile))
      file.remove(cacheFile)
   
   # remove any working data
   .rs.removeWorkingData(cacheKey)
   
   invisible(NULL)
})

.rs.addFunction("saveCachedData", function(cacheDir)
{
   # mark encoding on cache directory 
   if (Encoding(cacheDir) == "unknown")
      Encoding(cacheDir) <- "UTF-8"
   
   # no work to do if we have no cache
   if (!exists(".rs.CachedDataEnv")) 
      return(invisible(NULL))
   
   # save each active cache file from the cache environment
   lapply(ls(.rs.CachedDataEnv), function(cacheKey) {
      save(list = cacheKey, 
           file = file.path(cacheDir, paste(cacheKey, "Rdata", sep = ".")),
           envir = .rs.CachedDataEnv)
   })
   
   # clean the cache environment
   # can generate warnings if .rs.CachedDataEnv disappears (we call this on
   # shutdown); suppress these
   suppressWarnings(rm(list = ls(.rs.CachedDataEnv), where = .rs.CachedDataEnv))
   
   invisible(NULL)
})

.rs.addFunction("findWorkingData", function(cacheKey)
{
   if (exists(".rs.WorkingDataEnv") &&
       exists(cacheKey, where = .rs.WorkingDataEnv, inherits = FALSE))
      get(cacheKey, envir = .rs.WorkingDataEnv, inherits = FALSE)
   else
      NULL
})

.rs.addFunction("removeWorkingData", function(cacheKey)
{
   if (exists(".rs.WorkingDataEnv") &&
       exists(cacheKey, where = .rs.WorkingDataEnv, inherits = FALSE))
      rm(list = cacheKey, envir = .rs.WorkingDataEnv, inherits = FALSE)
   invisible(NULL)
})

.rs.addFunction("assignWorkingData", function(cacheKey, obj)
{
   assign(cacheKey, obj, .rs.WorkingDataEnv)
})

.rs.addFunction("findGlobalData", function(name)
{
   if (exists(name, envir = globalenv()))
   {
      if (inherits(get(name, envir = globalenv()), "data.frame"))
         return(name)
   }
   invisible("")
})

