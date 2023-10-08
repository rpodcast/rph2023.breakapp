#' auth_info UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd 
#'
#' @importFrom shiny NS tagList 
mod_auth_info_ui <- function(id){
  ns <- NS(id)
  tagList(
    auth0::logoutButton(),
    verbatimTextOutput(ns("user_info"))
  )
}
    
#' auth_info Server Functions
#'
#' @noRd 
mod_auth_info_server <- function(id){
  moduleServer( id, function(input, output, session){
    ns <- session$ns

    output$user_info <- renderPrint({
      session$userData$auth0_info
    })
 
  })
}
    
## To be copied in the UI
# mod_auth_info_ui("auth_info_1")
    
## To be copied in the server
# mod_auth_info_server("auth_info_1")
