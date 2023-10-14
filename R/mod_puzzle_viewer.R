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
  puzzleImageSrc = app_sys("app/www/images/exampleImg.jpg")
) {

  ns <- NS(id)
  tagList(
    shiny::fluidRow(
      shiny::column(
        width = 12,
        shiny::h2(titleText)
      )
    ),
    shiny::fluidRow(
      shiny::column(
        width = 8,
        shiny::img(
          src = base64enc::dataURI(file = puzzleImageSrc, mime = "image/jpeg"),
          height="100%",
          width="100%"
        ),
        # for some puzzles we have a reactable
        DT::DTOutput(
          outputId = ns("tablePuzzle"), 
          height="75%", 
          width="75%"
        )
      ),
      shiny::column(
        width = 4,
        # UI where they will answer the puzzle
        shiny::uiOutput(
          outputId = ns("answerUI")
        ),
        # Helper - penalizes time score by 5 mins?
        shiny::actionButton(
          inputId = ns("help"), 
          label = "Hint", 
          icon = shiny::icon("circle-question")
        )
      )
    )
  )
}
    
#' puzzle_viewer Server Functions
#'
#' @noRd 
mod_puzzle_viewer_server <- function(
  id,
  clues,
  answer,
  question_id,
  includeTablePuzzle = FALSE
  ){
  moduleServer( id, function(input, output, session){
    ns <- session$ns

    # define reactive values
    # listen to help and track number of times clicked
    helpCount <- reactiveVal(0)

    # create user input for answering puzzle
    output$answerUI <- shiny::renderUI(
      tagList(
        shiny::h2("Answer: "),
        textInput(
          inputId = ns("answer"), 
          label = answer$label,
        )
      )
    )

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
