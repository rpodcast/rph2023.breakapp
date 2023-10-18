#' puzzle_conclusion UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd 
#'
#' @importFrom shiny NS tagList 
mod_puzzle_conclusion_ui <- function(id, type = c("fail", "end")) {
  ns <- NS(id)
  type <- match.arg(type)

  image_file <- paste0(type, ".jpeg")
  tagList(
    shiny::h2(toupper(type)),
    shiny::img(src = file.path("www/images", image_file)),
    DT::DTOutput(ns("metrics_table"))
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
      download_user_df(con, user_nickname = user_info()$user_nickname)
    })

    output$metrics_table <- DT::renderDT({
      req(user_metrics())
      user_metrics()
    })
  })
}
    
## To be copied in the UI
# mod_puzzle_conclusion_ui("puzzle_conclusion_1")
    
## To be copied in the server
# mod_puzzle_conclusion_server("puzzle_conclusion_1")
