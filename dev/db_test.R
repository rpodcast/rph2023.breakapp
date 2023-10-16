# ensure .Renviron has the proper environment variables set up
library(DBI)
library(RPostgres)
library(dplyr)

devtools::load_all()

# docker container postgres db
con <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = Sys.getenv("PG_LOCAL_HOST"),
  dbname = Sys.getenv("PG_LOCAL_DB"),
  port = Sys.getenv("PG_LOCAL_PORT"),
  user = Sys.getenv("PG_LOCAL_USER"),
  password = Sys.getenv("PG_LOCAL_PASS")
)

import_quiz_data(con)

# debugging image as binary / raw test
res <- DBI::dbSendQuery(con, "DROP TABLE IF EXISTS imagetable;")
DBI::dbClearResult(res)

res <- DBI::dbSendQuery(
  con,
   "CREATE TABLE imagetable (
    image_column BYTEA
  );"
)
DBI::dbClearResult(res)

# Path to your image file
image_path <- "inst/app/www/images/puzzle1_dev.jpeg"

# Read binary data of the image file
image_data <- readBin(image_path, "raw", file.info(image_path)$size)
image_blob <- paste0("\\x", paste(image_data, collapse = ""))

# Prepare and execute the INSERT query
query <- "INSERT INTO imagetable (image_column) VALUES ($1)"
dbExecute(con, query, list(image_blob))

# Query to retrieve image data from the database
query <- "SELECT image_column FROM imagetable;"

# Execute the query and fetch the result
result <- dbGetQuery(con, query)

# Retrieve image data from the result
image_data2 <- result$image_column
image_data2_raw <- as.raw(image_data2[[1]])
# Write the image data to a file
writeBin(image_data2_raw, "dev/prototyping/puzzle1_dev.jpeg")




res <- DBI::dbSendQuery(con, "DROP TABLE IF EXISTS quizdata;")
DBI::dbClearResult(res)

res <- DBI::dbSendQuery(
  con,
   "CREATE TABLE quizdata (
    id VARCHAR NOT NULL,
    titleText VARCHAR,
    image_filename VARCHAR,
    image_blob BYTEA,
    clues JSONB,
    answers JSONB
  );"
)
DBI::dbClearResult(res)

quiz_list <- jsonlite::fromJSON(txt = "dev/prototyping/quiz_questions.json", simplifyDataFrame = FALSE, flatten = TRUE)


purrr::walk(quiz_list, ~{
  quiz_query <- "INSERT INTO quizdata (id, titleText, image_filename, image_blob, clues, answers)
  VALUES(
    {id},
    {titleText},
    {image_filename},
    {image_blob},
    {clues},
    {answers}
  );"

  image_dir <- "inst/app/www/images"
  image_raw <- readBin(file.path(image_dir, .x[["image_filename"]]), "raw", n = file.info(file.path(image_dir, .x[["image_filename"]]))$size)
  quiz_sql <- glue::glue_sql(
    quiz_query,
    id = .x[["id"]],
    titleText = .x[["titleText"]],
    image_filename = .x[["image_filename"]],
    image_blob = image_raw,
    image_blob = paste0("\\x", paste(image_raw, collapse = "")),
    clues = jsonlite::toJSON(.x[["clues"]], auto_unbox = TRUE, pretty = TRUE),
    answers = jsonlite::toJSON(.x[["answers"]], auto_unbox = TRUE, pretty = TRUE),
    .con = con
  )

  res <- DBI::dbSendQuery(con, quiz_sql)
  DBI::dbClearResult(res)
})

# grab data back
quiz_df_db <- DBI::dbReadTable(con, "quizdata")
user_df_db <- DBI::dbReadTable(con, "userdata")

bytea_data <- quiz_df_db$image_blob[1]
image_file <- quiz_df_db$image_filename[1]

extract_image_file(bytea_data, image_file)

bytea_data_raw <- as.raw(bytea_data[[1]])

writeBin(bytea_data_raw, con = "dev/prototyping/puzzle1_dev_from_db.jpeg")


res <- DBI::dbGetQuery(
  con,
  "SELECT id, answers->'answer' as ANSWER_VALUE FROM quizdata;"
)

res <- DBI::dbGetQuery(
  con,
  "SELECT * FROM quizdata;"
)

DBI::dbListTables(con)

DBI::dbDisconnect(con)

# digital ocean hosted postgres db
con <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = Sys.getenv("PG_SERVER_HOST"),
  dbname = Sys.getenv("PG_SERVER_DB"),
  port = Sys.getenv("PG_SERVER_PORT"),
  user = Sys.getenv("PG_SERVER_USER"),
  password = Sys.getenv("PG_SERVER_PASS")
)

DBI::dbListTables(con)
DBI::dbDisconnect(con)
