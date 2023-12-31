#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @import bslib
#' @noRd
app_ui <- function(request) {
  tagList(
    # Leave this function for adding external resources
    golem_add_external_resources(),
    # Your application UI logic
    page_navbar(
      title = "RPH2023 Escape App",
      id = "navbar",
      inverse = FALSE,

      nav_panel(
        title = "",
        value = 'intro',
        navset_hidden(
          id = 'tabs',
          nav_panel_hidden(
            value = "intro",
            card(
              full_screen = FALSE,
              card_body(
                h2("Welcome to the Escape Room"),
                shiny::img(src = 'www/images/intro.jpeg')
              )
            )
          )
        )
      ),
      nav_spacer(),
      nav_item(
        textOutput('n_rooms')
      ),
      nav_spacer(),
      nav_item(
        textOutput('hints_message')
      ),
      nav_spacer(),
      nav_item(
        textOutput('time_message')
      )
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path(
    "www",
    app_sys("app/www")
  )

  tags$head(
    favicon(),
    bundle_resources(
      path = app_sys("app/www"),
      app_title = "rph2023.breakapp"
    ),
    # Add here other external resources
    # for example, you can add shinyalert::useShinyalert()
    shinypop::use_noty(maxVisible = 3)
  )
}
