#' puzzle_viewer UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd 
#'
#' @importFrom shiny NS tagList 
mod_puzzle_viewer_ui <- function(
  id,
  titleText = "Example Puzzle",
  puzzleImageSrc = app_sys("app/www/images/exampleImg.jpg"),
  includeTablePuzzle = FALSE
) {

  ns <- NS(id)
  tagList(
    tags$div(
      #style = "width: 50%; height: auto;",
      shiny::img(
        src = base64enc::dataURI(file = puzzleImageSrc, mime = "image/jpeg")
      )
    ),
    if (includeTablePuzzle) {
      layout_columns(
        # for some puzzles we have a reactable
        DT::DTOutput(
          outputId = ns("tablePuzzle")
          #height="75%",
          #width="75%"
        )
      )
    },

    layout_columns(
      uiOutput(ns("answerUI")),
      actionButton(
        ns("submit"),
        label = "Submit"
      ),
      actionButton(
        inputId = ns("help"),
        label = "Hint",
        icon = shiny::icon("circle-question")
      )
    ),

    layout_columns(
      uiOutput(ns("prev_answers_display"))
    )
  )
}
    
#' puzzle_viewer Server Functions
#'
#' @noRd 
mod_puzzle_viewer_server <- function(
  id,
  con,
  user_info,
  timer,
  question_time,
  session_timestamp,
  clues,
  answer,
  question_id,
  parent_session,
  current_tab,
  n_questions,
  includeTablePuzzle = FALSE
  ){
  moduleServer( id, function(input, output, session){
    ns <- session$ns

    # define reactive values
    # listen to help and track number of times clicked
    helpCount <- reactiveVal(0)

    # track number of attempts
    attempts <- reactiveVal(0)

    # track incorrect answers already entered
    prev_answers <- reactiveVal(NULL)

    # escape room as complete or not
    quiz_complete <- reactiveVal(FALSE)

    # create user input for answering puzzle
    output$answerUI <- shiny::renderUI(
      tagList(
        textInput(
          inputId = ns("answer"),
          label = NULL,
          placeholder = "Enter answer here"
        )
      )
    )

    output$prev_answers_display <- shiny::renderUI({
      req(prev_answers())
      tagList(
        p("Your previous incorrect attempts:"),
        list_to_li(prev_answers())
      )
    })

    # reactive for answer status
    correct_ind <- reactive({
      req(input$answer)
      tolower(input$answer) == tolower(answer$answer)
    })

    if (includeTablePuzzle) {
      output$tablePuzzle <- DT::renderDT(
        DT::datatable(
          data = data.frame(
            a = rep('',5),
            b = rep('',5),
            c = rep('',5)
          ),
          options = list(dom = 't'),
          selection = list(target = "cell", mode = "multiple"),
          rownames = FALSE
        ),
        server = FALSE
      )
    }

    # Help Code
    observeEvent(input$help, {
      # add one to the help tracker
      helpCount(helpCount() + 1)

      # make sure the maxCount is less than or equal to the number of clues
      maxCount <- min(helpCount(), length(clues))

      # create text object with all the clues up to the maxCount
      output$helptext <- renderUI({
        list_to_li(clues[1:maxCount])
      })

      # display the hints
      shiny::showModal(
        shiny::modalDialog(
          uiOutput(ns('helptext')),
          title = "Hints",
          size = c("m"), # could try "s"
          easyClose = TRUE,
          fade = TRUE
        )
      )
    })

    observeEvent(input$submit, {
      req(current_tab())

      # increment attempts
      attempts(attempts() + 1)

      if (!current_tab() %in% c('intro', 'fail', 'end')) {
        tab_number <- as.integer(stringr::str_extract(current_tab(), "\\d+"))

        if (correct_ind()) {
          # move to end of puzzle if answered last question
          if (tab_number == n_questions) {
            next_tab <- 'end'
            quiz_complete(TRUE)
          } else {
            next_tab <- glue::glue("puzzle{tab_number + 1}_tab")
            quiz_complete(FALSE)
          }

          # send user answer data to database
          add_user_data(
            con,
            user_nickname = user_info()$user_nickname,
            user_name = user_info()$user_name,
            user_picture = user_info()$user_picture,
            session_timestamp = session_timestamp(),
            question_id = question_id,
            question_time = question_time(),
            overall_time = get_golem_config("quiz_time") - timer(),
            help_count = helpCount(),
            attempts = attempts(),
            quiz_complete = quiz_complete()
          )

          # reset individual question elapsed time
          question_time(0)

          # send notification to user
          shinypop::noty(text = "Correct answer!", timeout = 500, type= "success", layout = "center", killer = TRUE)

          # switch to next tab in escape room tab panel
          nav_select(
            session = parent_session,
            id = "tabs",
            selected = next_tab
          )
        } else {
          # track incorrect answer
          prev_answers(c(prev_answers(), input$answer))

          # clear the answer text input
          updateTextInput(
            session = session,
            inputId = "answer",
            value = "",
            placeholder = "Enter answer here"
          )
          # send notification to user
          shinypop::noty(text = "Incorrect! Try again...", timeout = 1000, type= "error", layout = "center", killer = TRUE)
        }
      }
    })

    # return answer status
    list(
      help_count = helpCount,
      correct_ind = correct_ind,
      user_answer = reactive(input$answer),
      question_id = question_id
    )
  })
}
    
## To be copied in the UI
# mod_puzzle_viewer_ui("puzzle_viewer_1")
    
## To be copied in the server
# mod_puzzle_viewer_server("puzzle_viewer_1")
