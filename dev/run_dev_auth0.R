# Set options here
options(golem.app.prod = FALSE) # TRUE = production mode, FALSE = development mode
#options(auth0_local = TRUE)

# Comment this if you don't want the app to be served on a random port
options(shiny.port = 2556)

options(auth0_config_file = system.file("app/_auth0.yml", package = "rph2023.breakapp"))

# Detach all loaded packages and clean your environment
golem::detach_all_attached()
# rm(list=ls(all.names = TRUE))

# Document and reload your package
golem::document_and_reload()

# Run the application
#run_app()
run_app_auth0()
