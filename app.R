library(shiny)
library(bslib)
library(DT)
library(ggplot2)
source("R/core.R")
ui <- page_sidebar(
  fillable = FALSE,
  title = "FareChecker · Travel insights",
  tags$head(tags$style(HTML(".bslib-grid, .card, .card-body {min-width:0; max-width:100%;} main.bslib-page-main, .bslib-sidebar-layout > .main, .bslib-sidebar-layout > main {min-width:0 !important; overflow-x:hidden;} .card-body {overflow-wrap:anywhere;} .shiny-plot-output img {max-width:100%; height:auto !important;} @media(max-width:1000px){.bslib-grid {grid-template-columns:minmax(0,1fr) !important; height:auto !important;} .bslib-grid > * {grid-column:1 / -1 !important;} }"))),
  theme = bs_theme(version = 5, bootswatch = "flatly", primary = "#126B67"),
  sidebar = sidebar(
    h4("Your travel, explained"),
    radioButtons("source", "Data source", c("Synthetic demonstration" = "demo", "Upload my file" = "upload")),
    conditionalPanel("input.source == 'upload'", fileInput("file", "Journey export", accept = c(".csv", ".xlsx", ".xls"))),
    checkboxInput("scope", "Confirm these are covered Translink services (excluding Airtrain and dedicated school buses)", FALSE),
    helpText("Demo records are fictional. Confirm service coverage to enable the 50-cent baseline."),
    uiOutput("dates"), textInput("route", "Search origin or destination"),
    downloadButton("download", "Export review records"),
    helpText("Uploaded records are processed in this R session; the app does not save them to disk. Hosting infrastructure has its own policies.")
  ),
  navset_card_tab(
    nav_panel("Overview", uiOutput("metrics"),
      layout_columns(card(card_header("Monthly journey charges"), plotOutput("spend")),
        card(card_header("Routes by spend"), plotOutput("routes"))),
      card(card_header("Balance history"), plotOutput("balance", height = 220)),
      p("Totals exclude possible duplicates and invalid/future dates. Journey counts represent transaction records, not reconstructed linked journeys. Adjustments and credits are shown separately.")),
    nav_panel("Fare review", p("Review suggestions are screening results, not confirmed overcharges or guaranteed refunds. Differences assume one covered journey per record."),
      DTOutput("reviews"), card(card_header("Why was this record flagged?"), uiOutput("explanation"))),
    nav_panel("Data quality", uiOutput("quality_summary"), DTOutput("quality"), h5("All transactions"), DTOutput("history")),
    nav_panel("Budget planner", p("Compare two user-defined commuting scenarios. These are assumptions, not live route quotes."),
      layout_columns(card(card_header("Current routine"), numericInput("days_a", "Days per week", 5, 0, 7), numericInput("trips_a", "Charged journeys per day", 2, 0, 20), numericInput("fare_a", "Fare per journey (AUD)", .5, 0, 100, .1)),
        card(card_header("Alternative routine"), numericInput("days_b", "Days per week", 3, 0, 7), numericInput("trips_b", "Charged journeys per day", 2, 0, 20), numericInput("fare_b", "Fare per journey (AUD)", .5, 0, 100, .1))),
      uiOutput("budget"), plotOutput("budget_plot", height = 280),
      p("Monthly estimates use 52 ÷ 12 weeks. Holidays, transfers, free travel and irregular travel are not modelled.")),
    nav_panel("Carbon & cost", 
      p("Compare one traveller's monthly public-transport and driving scenarios. Distances and factors are assumptions, not measurements from your uploaded records."),
      layout_columns(
        card(card_header("Travel routine"),
          numericInput("carbon_days", "Travel days per week", 5, 0, 7),
          numericInput("carbon_trips", "One-way journeys per day", 2, 0, 20),
          numericInput("pt_km", "Public transport distance per journey (km)", 10, 0, 1000),
          numericInput("car_km", "Driving distance per journey (km)", 10, 0, 1000)),
        card(card_header("Mode and emissions assumptions"),
          selectInput("carbon_mode", "Public transport mode / factor preset", c("Bus · UK 2025 proxy"="bus", "Coach · UK 2025 proxy"="coach", "Rail · illustrative assumption"="rail", "Other · custom assumption"="custom")),
          numericInput("pt_factor", "Public transport (g CO2e / passenger-km)", 103.85, 0, 2000, .01),
          numericInput("car_factor", "Car (g CO2e / vehicle-km)", 180, 0, 2000),
          numericInput("occupancy", "People sharing the car (including driver)", 1, 1, 10),
          sliderInput("variation", "Factor sensitivity (+/− %)", 0, 100, 20),
          uiOutput("factor_note"))),
      layout_columns(
        card(card_header("Public transport cost"), numericInput("carbon_fare", "Fare per one-way journey (AUD)", .5, 0, 100)),
        card(card_header("Driving cost"), numericInput("car_cost", "Car running cost (AUD / vehicle-km)", .3, 0, 10, .01), p("Illustrative running cost, shared by occupancy. Excludes parking, tolls and fixed ownership costs."))),
      uiOutput("carbon_result"), plotOutput("carbon_plot", height = 280),
      p("Sensitivity bounds vary both factors in opposite directions. They are not a statistical confidence interval. Estimates exclude vehicle manufacture, infrastructure and fuel supply-chain emissions; electricity-related boundaries vary by factor."),
      p("Bus and coach presets: UK DESNZ 2025 methodology, Table 25. These are frozen overseas examples, not Queensland fleet factors. Rail (50 g), car (180 g) and running cost ($0.30/km) defaults are illustrative assumptions. Replace them with locally appropriate, consistently bounded values."),
      tags$a(href="https://assets.publishing.service.gov.uk/media/6846b0870392ed9b784c0187/2025-GHG-CF-methodology-paper.pdf", target="_blank", "Factor source: UK DESNZ 2025 methodology")),
    nav_panel("Method & sources", includeMarkdown("docs/methodology.md"))
  )
)
server <- function(input, output, session) {
  imported <- reactive({
    if (input$source == "demo") return(read.csv("data/demo_transactions.csv", stringsAsFactors = FALSE, check.names = FALSE))
    req(input$file)
    tryCatch({
      ext <- tolower(tools::file_ext(input$file$name))
      if (ext == "csv") read.csv(input$file$datapath, stringsAsFactors = FALSE, check.names = FALSE)
      else if (ext %in% c("xls", "xlsx")) as.data.frame(readxl::read_excel(input$file$datapath))
      else stop("Choose a CSV or Excel file.")
    }, error = function(e) { validate(need(FALSE, conditionMessage(e))) })
  })
  all_data <- reactive({
    d <- tryCatch(prepare_data(imported()), error = function(e) { validate(need(FALSE, conditionMessage(e))) })
    analyze_fares(d, isTRUE(input$scope))
  })
  output$dates <- renderUI({
    dates <- all_data()$Date; dates <- dates[!is.na(dates)]
    if (!length(dates)) return(helpText("No valid dates to filter."))
    dateRangeInput("period", "Date range", start = min(dates), end = max(dates), min = min(dates), max = max(dates))
  })
  filtered <- reactive({
    d <- all_data()
    if (!is.null(input$period) && length(input$period) == 2 && !anyNA(input$period)) d <- d[!is.na(d$Date) & d$Date >= input$period[1] & d$Date <= input$period[2], , drop = FALSE]
    if (nzchar(input$route)) d <- d[grepl(tolower(input$route), tolower(d$Route), fixed = TRUE), , drop = FALSE]
    d
  })
  reviews <- reactive({ d <- filtered(); d[d$Status == "Review suggested", , drop = FALSE] })
  output$metrics <- renderUI({
    d <- metric_rows(filtered()); j <- d[d$Type == "Journey", , drop = FALSE]
    layout_columns(
      value_box("Journey charges", sprintf("$%.2f", sum(j$Fare, na.rm = TRUE))),
      value_box("Journey records", nrow(j)),
      value_box("Potential difference", sprintf("$%.2f", sum(j$Potential_Difference, na.rm = TRUE)), p("Assumed baseline; not an approved refund")),
      value_box("Credits / adjustments", sprintf("$%.2f", sum(d$Credit, na.rm = TRUE) - sum(d$Fare[d$Type == "Adjustment"], na.rm = TRUE))))
  })
  journey <- reactive({ d <- metric_rows(filtered()); d <- d[d$Type == "Journey", , drop = FALSE]; validate(need(nrow(d) > 0, "No journey records in this selection.")); d })
  output$spend <- renderPlot({
    d <- journey(); d$Month <- as.Date(format(d$Date, "%Y-%m-01"))
    a <- aggregate(Fare ~ Month, d, sum)
    ggplot(a, aes(Month, Fare)) + geom_col(fill = "#126B67", width = 20) + theme_minimal() + labs(x = NULL, y = "AUD")
  })
  output$routes <- renderPlot({
    a <- aggregate(Fare ~ Route, journey(), sum); a <- head(a[order(-a$Fare), ], 8)
    ggplot(a, aes(reorder(Route, Fare), Fare)) + geom_col(fill = "#126B67") + coord_flip() + theme_minimal() + labs(x = NULL, y = "AUD")
  })
  output$balance <- renderPlot({
    d <- metric_rows(filtered()); d <- d[!is.na(d$Timestamp) & !is.na(d$Balance), , drop = FALSE]
    validate(need(nrow(d) > 0, "No valid balances to display."))
    ggplot(d, aes(Timestamp, Balance)) + geom_line(color = "#126B67") + geom_point(color = "#126B67") + theme_minimal() + labs(x = NULL, y = "Balance (AUD)")
  })
  output$reviews <- renderDT({ datatable(reviews()[c("Record_ID", "Date", "From", "To", "Fare", "Expected_Fare", "Potential_Difference", "Reason")], rownames = FALSE, selection = "single", options = list(scrollX = TRUE, pageLength = 8)) })
  output$explanation <- renderUI({
    ids <- input$reviews_rows_selected; d <- reviews()
    if (!length(ids) || ids[1] > nrow(d)) return(p("Select a review record to see its reasoning."))
    r <- d[ids[1], ]; tagList(p(strong(paste("Record", r$Record_ID))), p(r$Reason), p(paste("Rule:", r$Rule)), p(paste("Data quality:", r$Quality)), p("Verify the original transaction and service before requesting an adjustment."))
  })
  output$quality_summary <- renderUI({
    d <- all_data(); tagList(p(sprintf("%s imported records · %s with quality issues · %s possible duplicate records", nrow(d), sum(d$Quality != "OK"), sum(d$Duplicate))), p("Quality results cover the full file. Records are retained for inspection; no automatic deduplication is performed."))
  })
  output$quality <- renderDT({ d <- all_data(); datatable(d[d$Quality != "OK", c("Record_ID", "Date", "Time", "Fare", "Credit", "Quality")], rownames = FALSE, options = list(scrollX = TRUE)) })
  output$history <- renderDT({ datatable(filtered()[c("Record_ID", "Date", "Time", "From", "To", "Fare", "Credit", "Balance", "Type", "Status", "Reason")], rownames = FALSE, options = list(scrollX = TRUE)) })
  output$download <- downloadHandler(filename = function() paste0("fare-review-", Sys.Date(), ".csv"), content = function(file) {
    d <- reviews(); d$Timestamp <- NULL
    # Neutralize spreadsheet formulas in user-provided text on CSV export.
    for (col in names(d)) if (is.character(d[[col]])) d[[col]] <- ifelse(grepl("^[[:space:]]*[=+@-]", d[[col]]), paste0("'", d[[col]]), d[[col]])
    write.csv(d, file, row.names = FALSE, na = "")
  })
  observeEvent(input$carbon_mode, {
    presets <- c(bus = 103.85, coach = 27.76, rail = 50)
    if (input$carbon_mode %in% names(presets)) updateNumericInput(session, "pt_factor", value = unname(presets[input$carbon_mode]))
  })
  output$factor_note <- renderUI({
    presets <- c(bus=103.85, coach=27.76, rail=50)
    baseline <- unname(presets[input$carbon_mode])
    if (input$carbon_mode %in% c("bus", "coach") && length(input$pt_factor) == 1 && isTRUE(all.equal(input$pt_factor, baseline)))
      p("UK 2025 operating-emissions proxy; average occupancy is already included. No extra occupancy division is applied to public transport.")
    else p("Custom / illustrative public transport factor. Check its source, year, geography and boundary before interpreting results.")
  })
  carbon <- reactive({
    tryCatch(carbon_scenario(input$carbon_days, input$carbon_trips, input$pt_km, input$car_km,
      input$pt_factor, input$car_factor, input$occupancy, input$variation, input$carbon_fare, input$car_cost),
      error = function(e) validate(need(FALSE, conditionMessage(e))))
  })
  output$carbon_result <- renderUI({
    c <- carbon()
    tagList(h4(sprintf("Monthly emissions: public transport %.2f · driving %.2f kg CO2e per traveller", c$pt, c$car)),
      p(sprintf("Driving minus public transport: %+.2f kg CO2e/month. Positive means public transport is lower; negative means driving is lower under these assumptions.", c$difference)),
      p(sprintf("Factor-sensitivity range for that difference: %+.2f to %+.2f kg CO2e/month.", c$lower, c$upper)),
      p(sprintf("Monthly cost: public transport $%.2f · driving share $%.2f. Driving minus public transport: %+.2f AUD.", c$pt_cost, c$car_cost, c$car_cost-c$pt_cost)))
  })
  output$carbon_plot <- renderPlot({
    c <- carbon()
    ggplot(data.frame(Mode=c("Public transport", "Driving share"), Emissions=c(c$pt,c$car)), aes(Mode,Emissions,fill=Mode)) +
      geom_col(width=.5) + scale_fill_manual(values=c("#CE9F42", "#126B67")) + theme_minimal() + guides(fill="none") + labs(x=NULL,y="Monthly kg CO2e per traveller")
  })
  budgets <- reactive({
    vals <- c(input$days_a, input$trips_a, input$fare_a, input$days_b, input$trips_b, input$fare_b)
    validate(need(length(vals) == 6 && all(is.finite(vals)) && all(vals >= 0) && input$days_a <= 7 && input$days_b <= 7, "Enter non-negative values; days per week must be between 0 and 7."))
    c(Current = commute_budget(input$days_a, input$trips_a, input$fare_a), Alternative = commute_budget(input$days_b, input$trips_b, input$fare_b))
  })
  output$budget <- renderUI({ b <- budgets(); p(sprintf("Current: $%.2f/month · Alternative: $%.2f/month · Difference (current minus alternative): $%.2f/month", b[1], b[2], b[1] - b[2])) })
  output$budget_plot <- renderPlot({ b <- budgets(); ggplot(data.frame(Scenario = names(b), Cost = unname(b)), aes(Scenario, Cost, fill = Scenario)) + geom_col(width = .5) + scale_fill_manual(values = c("#CE9F42", "#126B67")) + theme_minimal() + guides(fill = "none") + labs(x = NULL, y = "Monthly budget (AUD)") })
}
shinyApp(ui, server)
