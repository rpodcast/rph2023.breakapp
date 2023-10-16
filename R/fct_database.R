#' database helpers
#'
#' @description A fct function
#'
#' @return The return value, if any, from executing the function.
#'
#' @noRd
db_con <- function() {
  # define appropriate env variable names based on prod status
  if (Sys.getenv("R_CONFIG_ACTIVE") == "production") {
    env_string <- "SERVER"
  } else {
    env_string <- "LOCAL"
  }

  con <- pool::dbPool(
    RPostgres::Postgres(),
    host = Sys.getenv(glue::glue("PG_{env_string}_HOST")),
    dbname = Sys.getenv(glue::glue("PG_{env_string}_DB")),
    port = Sys.getenv(glue::glue("PG_{env_string}_PORT")),
    user = Sys.getenv(glue::glue("PG_{env_string}_USER")),
    password = Sys.getenv(glue::glue("PG_{env_string}_PASS"))
  )

  return(con)
}

create_user_table <- function(
  con,
  table_name = "userdata",
  overwrite_table = TRUE
) {
  if (overwrite_table) {
    res <- DBI::dbExecute(con, glue::glue("DROP TABLE IF EXISTS {table_name}"))
  }

  # define table schema
  res <- DBI::dbExecute(
    con,
    glue::glue("CREATE TABLE {table_name} (
      user_nickname VARCHAR NOT NULL,
      user_name VARCHAR,
      user_picture VARCHAR,
      session_timestamp TIMESTAMPTZ,
      question_id VARCHAR,
      question_time VARCHAR,
      overall_time VARCHAR,
      help_count NUMERIC,
      quiz_complete BOOLEAN
    );")
  )
}

import_quiz_data <- function(
  con, 
  quiz_file = "inst/app/quizfiles/quiz_questions_dev.json",
  image_dir = "inst/app/www/images",
  table_name = "quizdata",
  overwrite_table = TRUE
) {
  if (overwrite_table) {
    res <- DBI::dbExecute(con, glue::glue("DROP TABLE IF EXISTS {table_name}"))
  }

  # define table schema
  res <- DBI::dbExecute(
    con,
    glue::glue("CREATE TABLE {table_name} (
      id VARCHAR NOT NULL,
      titleText VARCHAR,
      image_filename VARCHAR,
      image_blob BYTEA,
      clues JSONB,
      answers JSONB,
      includeTablePuzzle BOOLEAN
    );")
  )

  # import quiz questions JSON file
  quiz_list <- jsonlite::fromJSON(txt = quiz_file, simplifyDataFrame = FALSE, flatten = TRUE)

  # import quiz questions to database table
  purrr::walk(quiz_list, ~{
    quiz_query <- "INSERT INTO {`table_name`} (id, titleText, image_filename, image_blob, clues, answers, includeTablePuzzle)
    VALUES(
      {id},
      {titleText},
      {image_filename},
      {image_blob},
      {clues},
      {answers},
      {includeTablePuzzle}
    );"

    image_raw <- readBin(file.path(image_dir, .x[["image_filename"]]), "raw", n = file.info(file.path(image_dir, .x[["image_filename"]]))$size)
    quiz_sql <- glue::glue_sql(
      quiz_query,
      table_name = table_name,
      id = .x[["id"]],
      titleText = .x[["titleText"]],
      image_filename = .x[["image_filename"]],
      image_blob = image_raw,
      image_blob = paste0("\\x", paste(image_raw, collapse = "")),
      clues = jsonlite::toJSON(.x[["clues"]], auto_unbox = TRUE, pretty = TRUE),
      answers = jsonlite::toJSON(.x[["answers"]], auto_unbox = TRUE, pretty = TRUE),
      includeTablePuzzle = .x[["includeTablePuzzle"]],
      .con = con
    )

    res <- DBI::dbExecute(con, quiz_sql)
  })
}

extract_image_file <- function(img_bytea, img_filename, output_dir = NULL) {
  img_raw <- as.raw(img_bytea[[1]])

  if (is.null(output_dir)) output_dir = tempdir()

  output_file <- file.path(output_dir, img_filename)
  writeBin(img_raw, con = output_file)
  return(output_file)
}

download_quiz_df <- function(con, table_name = "quizdata") {
  df <- DBI::dbReadTable(con, table_name)
  return(df)
}

extract_clues <- function(x) {
  jsonlite::fromJSON(x)
}

extract_answer <- function(x) {
  jsonlite::fromJSON(x)
}

add_user_data <- function(
  con,
  user_nickname,
  user_name,
  user_picture,
  session_timestamp,
  question_id,
  question_time,
  overall_time,
  help_count,
  quiz_complete,
  table_name = "userdata"
) {

  user_query <- "INSERT INTO {`table_name`} (user_nickname, user_name, user_picture, session_timestamp, question_id, question_time, overall_time, help_count, quiz_complete)
  VALUES(
    {user_nickname},
    {user_name},
    {user_picture},
    {session_timestamp},
    {question_id},
    {question_time},
    {overall_time},
    {help_count},
    {quiz_complete}
  );"

  user_sql <- glue::glue_sql(user_query, .con = con)

  res <- DBI::dbExecute(con, user_sql)
}