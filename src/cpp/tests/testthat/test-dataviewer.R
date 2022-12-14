#
# test-dataviewer.R
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

context("data viewer")

test_that(".rs.flattenFrame() handles matrices and data frames", {
   tbl1 <- data.frame(x = 1:2)
   df_col <- data.frame(y = 1:2, z = 1:2)
   tbl1$df_col <- df_col
   tbl1$mat_col <- matrix(1:4, ncol = 2)
   flat1 <- .rs.flattenFrame(tbl1)

   # same but matrix has colnames
   tbl2 <- tbl1
   tbl2$mat_col <- matrix(1:4, ncol = 2, dimnames = list(1:2, c("a", "b")))
   flat2 <- .rs.flattenFrame(tbl2)
   
   # further df nesting 
   tbl3 <- tbl2
   df_col$df <- df_col
   tbl3$df_col <- df_col
   flat3 <- .rs.flattenFrame(tbl3)

   expect_equal(names(flat1), c("x", "df_col$y", "df_col$z", "mat_col[,1]", "mat_col[,2]"))
   expect_equal(names(flat2), c("x", "df_col$y", "df_col$z", 'mat_col[,"a"]', 'mat_col[,"b"]'))
   expect_equal(names(flat3), c("x", "df_col$y", "df_col$z", "df_col$df$y", "df_col$df$z", 'mat_col[,"a"]', 'mat_col[,"b"]'))
})
