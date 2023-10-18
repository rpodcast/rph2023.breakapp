#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @import bslib
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
  show_result <- reactiveVal(FALSE)
  session_timestamp <- reactiveVal(Sys.time())

  # execute authentication information module
  user_info <- mod_auth_info_server("auth_info_1")

  # reactive for user check
  user_exists <- reactive({
    req(user_info()$user_nickname)

    res <- check_user_exists(con, user_info()$user_nickname)
    return(res)
  })

  # dynamically insert puzzle question UIs as new tabs
  observeEvent(start_app(), {
    purrr::walk(question_vec, ~{
      quiz_sub <- dplyr::slice(quiz_df, .x)

      nav_insert(
        id = "tabs",
        nav_panel_hidden(
          value = glue::glue("puzzle{.x}_tab"),
          card(
            full_screen = FALSE,
            fill = FALSE,
            card_body(
              h2(quiz_sub$titletext),
              mod_puzzle_viewer_ui(
                glue::glue("puzzle_viewer_{.x}"),
                titleText = quiz_sub$titletext,
                puzzleImageSrc = extract_image_file(quiz_sub$image_blob, quiz_sub$image_filename)
              )
            )
          )
        )
      )
    })

    # insert puzzle end tabs
    nav_insert(
      id = "tabs",
      position = "after",
      nav_panel_hidden(
        value = "end",
        card(
          full_screen = FALSE,
          card_body(
            mod_puzzle_conclusion_ui("puzzle_conclusion_end", type = "end")
          )
        )
      )
    )

    nav_insert(
      id = "tabs",
      position = "after",
      nav_panel_hidden(
        value = "fail",
        card(
          full_screen = FALSE,
          card_body(
            mod_puzzle_conclusion_ui("puzzle_conclusion_fail", type = "fail")
          )
        )
      )
    )

    # check if user exists already. If yes, show the wrap-up tab
    if (user_exists()) {
      if (check_quiz_complete(con, user_nickname = user_info()$user_nickname)) {
        next_tab <- 'end'
      } else {
        next_tab <- 'fail'
      }

      show_result(TRUE)

      nav_select(
        id = "tabs",
        selected = next_tab
      )
    } else {
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
          fade = TRUE,
          footer = tagList(
            actionButton(
              inputId = 'start',
              label = 'Start',
              icon = shiny::icon('hourglass-start')
            ),
            modalButton("Get me out of here!")
          )
        )
      )
    }
  })

  # reactive for current tab selected
  current_tab <- reactive({
    input$tabs
  })

  # execute server-side puzzle end/fail modules
  mod_puzzle_conclusion_server("puzzle_conclusion_end", con, user_info, show_result)
  mod_puzzle_conclusion_server("puzzle_conclusion_fail", con, user_info, show_result)

  # execute server-side puzzle question modules
  answers_res <- purrr::map(question_vec, ~{
    quiz_sub <- dplyr::slice(quiz_df, .x)
    mod_puzzle_viewer_server(
      glue::glue("puzzle_viewer_{.x}"),
      con = con,
      user_info = user_info,
      timer = timer,
      question_time,
      session_timestamp = session_timestamp,
      clues = extract_clues(quiz_sub$clues),
      answer = extract_answer(quiz_sub$answers),
      question_id = quiz_sub$id,
      parent_session = session,
      current_tab = current_tab,
      n_questions = n_questions
    )
  })



  # display instructions when requested
  # observeEvent(input$info, {
  #   shiny::showModal(
  #     shiny::modalDialog(
  #       title = "Instructions for the escape room",
  #       shiny::p(
  #         glue::glue("Once you click 'Start' you will have {get_golem_config('quiz_time') / 60} minutes to solve a set of puzzles.")
  #       ),
  #       shiny::p(
  #         "Each puzzles requires a number or word to be entered.  
  #         If correct, a new puzzle will be presented or you will escape the room.  
  #         If incorrect, nothing will happen."
  #       ),
  #       shiny::p(
  #         "You can use (and will need to use) the internet to help solve some puzzles."
  #       ),
  #       size = c("m"), # could try "s"
  #       easyClose = TRUE,
  #       fade = TRUE
  #     )
  #   )
  # })

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
          nav_select(
            id = "tabs",
            selected = "fail"
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
    removeModal()
    
    # start timer
    active(TRUE)
    
    # move to puzzle 1
    nav_select(
      id = "tabs",
      selected = "puzzle1_tab"
    )
  })

  observeEvent(current_tab(), {
    if (current_tab() %in% c('fail', 'end')) {
      active(FALSE)
      show_result(TRUE)
    }
  })

  # move to next puzzle on submit if answer is correct
  # observeEvent(input$submit, {
  #   req(current_tab())
  #   if (!current_tab() %in% c('intro', 'fail', 'end')) {
  #     tab_number <- as.integer(stringr::str_extract(current_tab(), "\\d+"))

  #     if (answers_res[[tab_number]]$correct_ind()) {
  #       # move to end of puzzle if answered last question
  #       if (tab_number == n_questions) {
  #         next_tab <- 'end'
  #         quiz_complete <- TRUE
  #         active(FALSE)
  #       } else {
  #         next_tab <- glue::glue("puzzle{tab_number + 1}_tab")
  #         quiz_complete <- FALSE
  #       }

  #       # send user answer data to database
  #       add_user_data(
  #         con,
  #         user_nickname = user_info()$user_nickname,
  #         user_name = user_info()$user_name,
  #         user_picture = user_info()$user_picture,
  #         session_timestamp = session_timestamp(),
  #         question_id = answers_res[[tab_number]]$question_id,
  #         question_time = question_time(),
  #         overall_time = get_golem_config("quiz_time") - timer(),
  #         help_count = answers_res[[tab_number]]$help_count(),
  #         quiz_complete = quiz_complete
  #       )

  #       # reset individual question elapsed time
  #       question_time(0)

  #       nav_select(
  #         id = "tabs",
  #         selected = next_tab
  #       )
  #     }
  #   }
  # })
}
