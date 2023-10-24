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
  room_counter <- reactiveVal(0)
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
  observeEvent(user_info()$user_nickname, {
    req(user_info()$user_nickname)
    # message("Starting app")
    # message(user_info()$user_nickname)
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
                puzzleImageSrc = extract_image_file(quiz_sub$image_blob, quiz_sub$image_filename),
                includeTablePuzzle = quiz_sub$includetablepuzzle
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

    # check if user exists already
    # - If yes, show the wrap-up tab and do not add additional record to database
    # - If no, add event record of logging in to the app after they hit start
    if (user_exists() & !get_golem_config("allow_multiple_attempts")) {
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
      n_questions = n_questions,
      includeTablePuzzle = quiz_sub$includetablepuzzle
    )
  })

  # track total number of hints used
  total_hints <- reactive({
    if (user_exists() & !get_golem_config("allow_multiple_attempts"))  {
      df <- download_user_df(con, user_nickname = user_info()$user_nickname)
      hints_total <- sum(df$help_count)
    } else {
      hints_vec <- purrr::map_int(question_vec, ~{
        req(answers_res[[.x]]$help_count())
        answers_res[[.x]]$help_count()
      })
      hints_total <- sum(hints_vec)
    }

    return(hints_total)
  })

  # track total number of incorrect answer attempts
  total_incorrect <- reactive({
    if (user_exists() & !get_golem_config("allow_multiple_attempts")) {
      df <- download_user_df(con, user_nickname = user_info()$user_nickname)
      attempts_total <- sum(df$attempts)
    } else {
      hints_vec <- purrr::map_int(question_vec, ~{
        req(answers_res[[.x]]$attempts())
        answers_res[[.x]]$attempts()
      })
      attempts_total <- sum(hints_vec)
    }
    return(attempts_total)
  })

  # subtract seconds from total time left
  observeEvent(total_incorrect(), {
    if (!user_exists() & get_golem_config("allow_multiple_attempts")) {
      if (total_incorrect() > 0) {
        timer(timer() - (get_golem_config("penalty_time") * total_incorrect()))
      }
    }
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

  # render number of rooms solved
  output$n_rooms <- renderText({
    req(room_counter())
    paste("Rooms solved: ", room_counter())
  })

  # render number of hints used
  output$hints_message <- renderText({
    req(total_hints())
    paste("Hints used: ", total_hints())
  })

  # when user clicks begin button move to first puzzle
  observeEvent(input$start, {
    removeModal()

    add_user_data(
      con,
      user_nickname = user_info()$user_nickname,
      user_name = user_info()$user_name,
      user_picture = user_info()$user_picture,
      session_timestamp = session_timestamp(),
      event_type = "start_session",
      question_id = NA,
      question_time = 0,
      overall_time = timer() - get_golem_config("penalty_time"),
      hint_counter = 0,
      attempt_counter = 0,
      user_answer = NA,
      correct_answer_ind = FALSE,
      proportion_complete = 0,
      quiz_complete = FALSE
    )
    
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
      room_counter(n_questions)
    } else {
      tab_number <- as.integer(stringr::str_extract(current_tab(), "\\d+"))
      room_counter(tab_number - 1)
    }
  })
}
