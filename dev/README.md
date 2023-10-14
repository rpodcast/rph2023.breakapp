# Escape Room Application Developer Guide

This document contains additional details on setting up a development environment for building the Escape Room application as well as information on additional services utilized in the backend. The application leverages a custom database for backend storage.

## Development Environment

Refer to these [instructions](https://github.com/rpodcast/r_dev_projects/blob/main/.devcontainer/README.md) for how to set up your environment to use this container setup. Note that the port used for the RStudio container is set to `3334`, hence you would visit `localhost:3334` in your web browser to access the RStudio web interface for the container. 

## Environment Variables

Each of the services discussed in this document require authentication keys stored as environment variables. The `.Renviron.example` file contains the variables alongside placeholder keys. Contact the author of this application for the real values of these variables and create a new `.Renviron` file in the root of this repository with the correct values. Note that this file will not be version-controlled. 

## Authentication

The production version of the escape room application uses the [Auth0](https://auth0.com/) service in order to track a user's answers and time elapsed for the escape room riddles. When executing the application in development mode, the Auth0 portal is bypassed and a test user is automatically tracked in the application. If you want to execute the Auth0 login portal in a development context, edit the `dev/run_dev.R` script and set `options(auth0_disable = FALSE)`. Make sure to switch it back to `options(auth0_disable = TRUE)` after finishing your ad-hoc testing.

Note: When using the Auth0 feature, you must open the application in a web browser tab. The RStudio viewer tab as well as Visual Studio Code's internal app viewer tab are not able to render the application correctly. 

At the time of this writing, the Auth0 login portal supports the following social logins:

* Amazon
* Bitbucket
* Discord
* Dropbox
* GitHub
* Slack

In addition, the user can create a login with an email address and password. 

## Database

This application leverages a [PostgreSQL](https://www.postgresql.org/) database to store the escape room questions & answers, as well as metrics from the logged-in user. The [`{DBI}`](https://www.r-dbi.org/) and [`{RPostgres}`](https://rpostgres.r-dbi.org/) packages are used to facilitate the database operations inside the R processes. 

In development mode, the database is available as another Docker container, and the necessary environment variables and values can be used as-is from the `.Renviron.example` template (since the container is local on your system and not accessible from the outside world).

In production mode, the database is hosted on a [Digital Ocean]() hosted PostgreSQL database instance. Contact the application author for the necessary environment variable values to include in your `.Renviron` file.

All functions supporting database operations are contained in the `R/fct_database.R` script.

Before proceeding with the database operations, ensure the following requirements are met:

* Populate your local `.Renviron` file with the appropriate variable values.
* Create a production copy of the escape room quiz questions a& answers JSON file using the same structure as in the development version JSON file located in the `inst/app/quizfiles/quiz_questions_dev.json` and store the file in `dev/prototyping/quiz_questions_prod.json`. In addition, ensure the escape room question image files are stored in the `dev/prototyping/images` directory.

To initialize the database tables, use the `dev/initialize_db_tables.R` script. To switch between development and production mode, uncomment the appropriate `Sys.setenv()` calls as noted in the script.

