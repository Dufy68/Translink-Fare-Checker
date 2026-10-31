# Pure functions: no Shiny state or network calls.
parse_money <- function(x) {
  x <- trimws(as.character(x))
  blank <- is.na(x) | x == ""
  wrapped <- grepl("^\\(.*\\)$", x)
  cleaned <- gsub("[$,[:space:]()]", "", x)
  valid <- grepl("^[+-]?[0-9]+(\\.[0-9]{1,2})?$", cleaned)
  out <- suppressWarnings(as.numeric(ifelse(valid, cleaned, NA_character_)))
  out[wrapped & !is.na(out)] <- -abs(out[wrapped & !is.na(out)])
  out[blank] <- NA_real_
  out
}
parse_dates <- function(x) {
  x <- trimws(as.character(x))
  iso <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)
  result <- as.Date(rep(NA_character_, length(x)))
  result[iso] <- as.Date(x[iso], format = "%Y-%m-%d")
  result[!iso] <- as.Date(x[!iso], format = "%d/%m/%Y")
  result
}
prepare_data <- function(raw) {
  names(raw) <- trimws(names(raw))
  required <- c("Date", "Time", "From", "To", "Fare", "Credit", "Balance")
  missing <- setdiff(required, names(raw))
  if (length(missing)) stop(paste("Missing columns:", paste(missing, collapse = ", ")))
  if (anyDuplicated(names(raw))) stop("Column names must be unique.")
  if (!nrow(raw)) stop("The file contains no transactions.")
  d <- raw
  d$Record_ID <- seq_len(nrow(d))
  d$Date <- parse_dates(d$Date)
  d$Time <- trimws(as.character(d$Time))
  for (col in c("From", "To")) {
    d[[col]] <- trimws(as.character(d[[col]]))
    d[[col]][is.na(d[[col]])] <- ""
  }
  for (col in c("Fare", "Credit", "Balance")) d[[col]] <- parse_money(d[[col]])
  duplicate <- duplicated(raw[required]) | duplicated(raw[required], fromLast = TRUE)
  valid_time <- !is.na(d$Time) & grepl("^([01]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$", d$Time)
  d$Quality <- vapply(seq_len(nrow(d)), function(i) {
    issues <- c(if (is.na(d$Date[i])) "Invalid date",
      if (!valid_time[i]) "Invalid time",
      if (is.na(d$Balance[i])) "Missing/invalid balance",
      if (is.na(d$Fare[i])) "Missing/invalid fare",
      if (is.na(d$Credit[i])) "Missing/invalid credit",
      if (duplicate[i]) "Possible duplicate",
      if (!nzchar(d$From[i]) || !nzchar(d$To[i])) "Missing stop")
    if (!length(issues)) "OK" else paste(issues, collapse = "; ")
  }, character(1))
  d$Duplicate <- duplicate
  d$Type <- "Unresolved"
  fare <- d$Fare; credit <- d$Credit
  d$Type[!is.na(fare) & fare > 0 & (is.na(credit) | credit == 0)] <- "Journey"
  d$Type[!is.na(fare) & fare == 0 & !is.na(credit) & credit == 0 & nzchar(d$From) & nzchar(d$To)] <- "Journey"
  d$Type[!is.na(fare) & fare == 0 & !is.na(credit) & credit > 0] <- "Top-up / credit"
  d$Type[!is.na(fare) & fare < 0] <- "Adjustment"
  d$Type[!is.na(fare) & fare > 0 & !is.na(credit) & credit > 0] <- "Mixed transaction"
  d$Route <- paste(d$From, d$To, sep = " → ")
  d$Timestamp <- as.POSIXct(paste(d$Date, d$Time), format = "%Y-%m-%d %H:%M", tz = "Australia/Brisbane")
  d[order(d$Date, d$Timestamp, d$Record_ID, na.last = TRUE), ]
}
analyze_fares <- function(d, confirm_scope = FALSE, as_of = Sys.Date()) {
  d$Status <- "Needs information"
  d$Reason <- "Confirm the service is covered; missing data cannot establish a fare."
  d$Rule <- "UNASSESSED"
  d$Expected_Fare <- NA_real_
  d$Potential_Difference <- NA_real_
  for (i in seq_len(nrow(d))) {
    if (d$Duplicate[i]) {
      d$Reason[i] <- "Possible duplicate: excluded from totals until resolved."
      next
    }
    if (d$Type[i] != "Journey") {
      d$Reason[i] <- paste(d$Type[i], "record; not assessed as a journey.")
      d$Status[i] <- if (d$Type[i] %in% c("Adjustment", "Top-up / credit")) "Not assessed" else "Needs information"
      next
    }
    if (is.na(d$Date[i]) || d$Date[i] > as_of) { d$Reason[i] <- "Missing, invalid or future journey date."; next }
    if (d$Date[i] < as.Date("2024-08-05")) { d$Reason[i] <- "Historical zone pricing is outside the implemented rule set."; next }
    airport <- grepl("airtrain|airport|domestic terminal|international terminal", d$Route[i], ignore.case = TRUE)
    if (airport) { d$Reason[i] <- "Possible Airtrain journey: the flat-fare rule is not applicable."; next }
    if (!confirm_scope || !nzchar(d$From[i]) || !nzchar(d$To[i])) next
    d$Rule[i] <- "QLD_FLAT_2024_08_05"
    d$Expected_Fare[i] <- 0.50
    cents <- round(d$Fare[i] * 100)
    failed <- grepl("fail|missed|not touch|not tap", d$Route[i], ignore.case = TRUE)
    if (cents > 50) {
      d$Status[i] <- "Review suggested"
      d$Potential_Difference[i] <- (cents - 50) / 100
      d$Reason[i] <- if (cents == 250) "Matches the current standard default-fare amount; check tap records. Adjustment eligibility is not established." else "Above the assumed 50-cent journey fare; verify service, transaction meaning and tap records."
    } else if (failed) {
      d$Status[i] <- "Review suggested"
      d$Reason[i] <- "Tap failure text detected; no positive fare difference established."
    } else if (cents == 50) {
      d$Status[i] <- "Within baseline"
      d$Potential_Difference[i] <- 0
      d$Reason[i] <- "Matches the 50-cent baseline under the confirmed scope."
    } else {
      d$Status[i] <- "Review context"
      d$Potential_Difference[i] <- 0
      d$Reason[i] <- "Below baseline: may be a transfer, free journey or adjustment; not evidence of a failed tap."
    }
  }
  d
}
metric_rows <- function(d) d[!d$Duplicate & !is.na(d$Date) & d$Date <= Sys.Date(), , drop = FALSE]
commute_budget <- function(days, trips, fare, weeks = 52/12) {
  stopifnot(all(is.finite(c(days, trips, fare, weeks))), days >= 0, days <= 7, trips >= 0, fare >= 0, weeks >= 0)
  round(days * trips * fare * weeks, 2)
}

# Scenario estimates, independent of transaction counts. Factors are g CO2e/km.
carbon_scenario <- function(days, trips, pt_km, car_km, pt_factor, car_factor,
                            occupancy = 1, variation = 20, fare = .5, car_cost = .3) {
  values <- list(days, trips, pt_km, car_km, pt_factor, car_factor, occupancy, variation, fare, car_cost)
  if (!all(vapply(values, function(x) is.numeric(x) && length(x) == 1 && is.finite(x), logical(1)))) stop("Enter a finite number in every scenario field.")
  if (any(unlist(values) < 0) || days > 7 || occupancy < 1 || variation > 100) stop("Use non-negative values, 0–7 days, occupancy of at least 1 and variation of 0–100%.")
  journeys <- days * trips * 52/12
  pt <- journeys * pt_km * pt_factor / 1000
  car <- journeys * car_km * car_factor / occupancy / 1000
  v <- variation / 100
  list(journeys = journeys, pt = pt, car = car, difference = car - pt,
       lower = car * (1-v) - pt * (1+v), upper = car * (1+v) - pt * (1-v),
       pt_cost = journeys * fare, car_cost = journeys * car_km * car_cost / occupancy)
}
