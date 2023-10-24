#' puzzle_conclusion UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd 
#'
#' @importFrom shiny NS tagList 
#' @import bslib
mod_puzzle_conclusion_ui <- function(id, type = c("fail", "end")) {
  ns <- NS(id)
  type <- match.arg(type)

  image_file <- paste0(type, ".jpeg")
  tagList(
    layout_columns(
      fill = FALSE,
      value_box(
        title = "Time",
        value = textOutput(ns("escape_value"), inline = TRUE),
        showcase = bsicons::bs_icon("hourglass-split")
      ),
      value_box(
        title = "Rooms Escaped",
        value = textOutput(ns("correct_value"), inline = TRUE),
        showcase = bsicons::bs_icon("unlock")
      ),
      value_box(
        title = "Total Hints",
        value = textOutput(ns("hints_value"), inline = TRUE),
        showcase = bsicons::bs_icon("info-circle")
      ),
      value_box(
        title = "Incorrect Attempts",
        value = textOutput(ns("attempts_value"), inline = TRUE),
        showcase = bsicons::bs_icon("x-octagon")
      )
    ),
    shiny::img(src = file.path("www/images", image_file))
  )
}
    
#' puzzle_conclusion Server Functions
#'
#' @noRd 
mod_puzzle_conclusion_server <- function(id, con, user_info, show_result){
  moduleServer( id, function(input, output, session){
    ns <- session$ns

    user_metrics <- reactive({
      req(user_info()$user_name)
      req(show_result())
      user_df <- download_user_df(con, user_nickname = user_info()$user_nickname)
      tidy_metrics(user_df)
    })

    output$escape_value <- renderText({
      req(user_metrics())
      prettyunits::pretty_sec(user_metrics()$total_time)
    })

    output$correct_value <- renderText({
      req(user_metrics())
      prettyNum(user_metrics()$total_correct)
    })

    output$hints_value <- renderText({
      req(user_metrics())
      prettyNum(user_metrics()$total_hints)
    })

    output$attempts_value <- renderText({
      req(user_metrics())
      prettyNum(user_metrics()$total_incorrect_attempts)
    })
  })
}
    
## To be copied in the UI
# mod_puzzle_conclusion_ui("puzzle_conclusion_1")
    
## To be copied in the server
# mod_puzzle_conclusion_server("puzzle_conclusion_1")
