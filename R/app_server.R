#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # establish database connection
  con <- db_con()

  # close connection when exiting app
  onStop(function() {
    pool::poolClose(con)
  })

  # download quiz data
  quiz_df <- download_quiz_df(con)
  n_questions <- nrow(quiz_df)
  question_vec <- seq_len(n_questions)

  # establish reactive values
  start_app <- reactiveVal(TRUE)
  timer <- reactiveVal(get_golem_config("quiz_time"))
  question_time <- reactiveVal(0)
  active <- reactiveVal(FALSE)
  session_timestamp <- reactiveVal(Sys.time())

  # execute authentication information module
  user_info <- mod_auth_info_server("auth_info_1")

  # dynamically insert puzzle question UIs as new tabs
  observeEvent(start_app(), {
    purrr::walk(question_vec, ~{
      quiz_sub <- dplyr::slice(quiz_df, .x)
      
      insertTab(
        inputId = "tabs",
        tabPanel(
          title = glue::glue("Tab {.x}"),
          value = glue::glue("puzzle{.x}_tab"),
          mod_puzzle_viewer_ui(
            glue::glue("puzzle_viewer_{.x}"),
            titleText = quiz_sub$titletext,
            puzzleImageSrc = extract_image_file(quiz_sub$image_blob, quiz_sub$image_filename)
          )
        )
      )
    })

    # insert puzzle end tabs
    insertTab(
      inputId = "tabs",
      tabPanel(
        title = 'End',
        value = "end",
        position = "after",
        shiny::h1("Congratulations you escaped..."),
        shiny::img(src = "www/images/end.jpeg")
      )
    )

    insertTab(
      inputId = "tabs",
      tabPanel(
        title = 'Fail',
        value = "fail",
        position = "after",
        shiny::h1("Sorry, you did not escape"),
        shiny::img(src = "www/images/fail.jpeg")
      )
    )
  })

  # reactive for current tab selected
  current_tab <- reactive({
    input$tabs
  })

  # execute server-side puzzle question modules
  answers_res <- purrr::map(question_vec, ~{
    quiz_sub <- dplyr::slice(quiz_df, .x)
    mod_puzzle_viewer_server(
      glue::glue("puzzle_viewer_{.x}"),
      clues = extract_clues(quiz_sub$clues),
      answer = extract_answer(quiz_sub$answers),
      question_id = quiz_sub$id,
      includeTablePuzzle = quiz_sub$includetablepuzzle
    )
  })

  # display instructions when requested
  observeEvent(input$info, {
    shiny::showModal(
      shiny::modalDialog(
        title = "Instructions for the escape room",
        shiny::p(
        glue::glue("Once you click 'Start' you will have {get_golem_config('quiz_time') / 60} minutes to solve a set of puzzles.")
        ),
        shiny::p(
          "Each puzzles requires a number or word to be entered.  
          If correct, a new puzzle will be presented or you will escape the room.  
          If incorrect, nothing will happen."
        ),
        shiny::p(
          "You can use (and will need to use) the internet to help solve some puzzles."
        ),
        size = c("m"), # could try "s"
        easyClose = TRUE,
        fade = TRUE
      )
    )
  })

  # run the timer when quiz begins
  observe({
    invalidateLater(1000, session)
    isolate({
      if(active()) {
        question_time(question_time() + 1)
        timer(timer() - 1)
        if(timer() < 1) {
          active(FALSE)
          shiny::showModal(
            shiny::modalDialog(
              title = "Time is up",
              "Countdown completed!"
            )
          )
          updateTabsetPanel(
            session = session, 
            inputId = 'tabs', 
            selected = 'fail'
          )
        }
      }
    })
  })

  # render time remaining
  output$time_message <- renderText({
    paste("Time left: ", lubridate::seconds_to_period(timer()))
  })

  # when user clicks begin button move to first puzzle
  observeEvent(input$start, {
    # start timer
    active(TRUE)
    
    # move to puzzle 1
    updateTabsetPanel(
      inputId = 'tabs', 
      selected = 'puzzle1_tab'
    )
  })

  # move to next puzzle on submit if answer is correct
  observeEvent(input$submit, {
    req(current_tab())
    if (!current_tab() %in% c('intro', 'fail', 'end')) {
      tab_number <- as.integer(stringr::str_extract(current_tab(), "\\d+"))

      if (answers_res[[tab_number]]$correct_ind()) {
        # move to end of puzzle if answered last question
        if (tab_number == n_questions) {
          next_tab <- 'end'
          quiz_complete <- TRUE
          active(FALSE)
        } else {
          next_tab <- glue::glue("puzzle{tab_number + 1}_tab")
          quiz_complete <- FALSE
        }

        # send user answer data to database
        add_user_data(
          con,
          user_nickname = user_info()$user_nickname,
          user_name = user_info()$user_name,
          user_picture = user_info()$user_picture,
          session_timestamp = session_timestamp(),
          question_id = answers_res[[tab_number]]$question_id,
          question_time = question_time(),
          overall_time = get_golem_config("quiz_time") - timer(),
          help_count = answers_res[[tab_number]]$help_count(),
          quiz_complete = quiz_complete
        )

        # reset individual question elapsed time
        question_time(0)

        updateTabsetPanel(
          inputId = 'tabs',
          selected = next_tab
        )
      }
    }
  })
}
