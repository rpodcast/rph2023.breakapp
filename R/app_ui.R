#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_ui <- function(request) {
  tagList(
    # Leave this function for adding external resources
    golem_add_external_resources(),
    # Your application UI logic
    fluidPage(
      #mod_auth_info_ui("auth_info_1")
      h1("Escape the RPH2023"),
      
      tabsetPanel(
        id = 'tabs',
        type = 'hidden',

        # welcome tab
        tabPanel(
          title = 'Welcome to the escape room',
          value = "intro",
          column(
            width = 10,
            shiny::img(src = 'www/images/intro.jpeg')
          ),
          column(
            width = 2,
            actionButton(
              'start',
              label = 'Start',
              icon = shiny::icon('hourglass-start')
            ),
            actionButton(
              'info',
              label = 'Instructions',
              icon = shiny::icon('info')
            ),
            mod_auth_info_ui("auth_info_1")
          )
        ),

        # time display
        footer = tagList(
          textOutput('time_message'),
          actionButton("submit", label = "Submit")
        )
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
    )
    # Add here other external resources
    # for example, you can add shinyalert::useShinyalert()
  )
}
