#' Cellosaurus table of cell identifier mappings
#'
#' @export
#' @note Updated 2021-02-21.
#'
#' @param x `character`.
#'   Cellosaurus cell line identifiers (e.g. `CVCL_*`.)
#'
#' @return `DataFrame`.
#'
#' @examples
#' cells <- c("CVCL_0126", "CVCL_1045")
#' object <- CellosaurusTable(cells)
#' print(object)
CellosaurusTable <-  # nolint
    function(x) {
        assert(
            isCharacter(x),
            allAreMatchingFixed(x, "CVCL_")
        )
        list <- lapply(
            X = x,
            FUN = function(id) {
                url <- pasteURL(
                    "web.expasy.org",
                    "cellosaurus",
                    paste0(id, ".txt"),
                    protocol = "https"
                )
                response <- GET(url)
                content <- content(response, as = "text")
                lines <- strsplit(content, split = "\n")[[1L]]
                out <- list(
                    "cellosaurusId" = id,
                    "cellLineName" = .strSubsetAndMatchSingle(
                        string = head(lines, n = 1L),
                        pattern = "^<pre>ID[[:space:]]+(.+)$"
                    ),
                    "isCancer" = any(str_detect(
                        string = lines,
                        pattern = "^CA[[:space:]]+Cancer cell line$"
                    )),
                    "isProblematic" = any(str_detect(
                        string = lines,
                        pattern = "^CC[[:space:]]+Problematic cell line.*$"
                    )),
                    "organism" = .strSubsetAndMatchSingle(
                        string = lines,
                        pattern = "^OX.+! (.+)$"
                    ),
                    "patientAgeYears" = as.integer(.strSubsetAndMatchSingle(
                        string = lines,
                        pattern = "^AG[[:space:]]+([0-9]+)Y$"
                    )),
                    "patientSex" = .strSubsetAndMatchSingle(
                        string = lines,
                        pattern = "^SX[[:space:]]+(.+)$"
                    )
                )
                assert(
                    isString(out[["cellLineName"]]),
                    isFlag(out[["isCancer"]]),
                    isFlag(out[["isProblematic"]]),
                    isOrganism(out[["organism"]]),
                    isInt(out[["patientAgeYears"]]) ||
                        is.na(out[["patientAgeYears"]]),
                    isSubset(out[["patientSex"]], c("Female", "Male"))
                )
                ## Disease: NCIt.
                ## Note that we're censoring problematic cell lines here.
                match <- .strSubsetAndMatch(
                    string = lines,
                    pattern = "^DI[[:space:]]+NCIt; (C[0-9]+); (.+)$"
                )
                if (hasRows(match) && !isTRUE(out[["isProblematic"]])) {
                    out[["ncitDiseaseId"]] <- match[1L, 2L]
                    out[["ncitDiseaseName"]] <- match[1L, 3L]
                } else {
                    ## nocov start
                    ncitDiseaseId <- NA_character_
                    ncitDiseaseName <- NA_character_
                    ## nocov end
                }
                ## Filter entries with "DR" tag.
                dr <- str_match(
                    string = lines,
                    pattern = "^DR[[:space:]]+(.+); (.+)$"
                )
                dr <- dr[complete.cases(dr), c(2L, 3L), drop = FALSE]
                colnames(dr) <- c("key", "value")
                keep <- dr[, 1L] %in% c(
                    ## Cell line databases / resource.
                    "CCLE",
                    "Cell_Model_Passport",
                    "Cosmic-CLP",
                    "DepMap",
                    "LINCS_HMS",
                    "LINCS_LDP",
                    ## Ontologies:
                    "BTO",
                    "CLO",
                    "EFO",
                    "MCCL"
                )
                dr <- dr[keep, , drop = FALSE]
                dr <- dr[order(dr[, "key"], dr[, "value"]), , drop = FALSE]
                dr <- aggregate(
                    formula = formula("value~key"),
                    data = dr,
                    FUN = list
                )
                assert(is.data.frame(dr))
                dr2 <- dr[["value"]]
                names(dr2) <- dr[["key"]]
                out <- append(x = out, values = dr2)
                names(out) <- camelCase(names(out), strict = TRUE)
                out
            }
        )
        names(list) <- x
        df <- rbindToDataFrame(list)
        df <- df[, sort(colnames(df)), drop = FALSE]
        assert(
            is(df, "DataFrame"),
            identical(rownames(df), x)
        )
        new("CellosaurusTable", df)
    }
