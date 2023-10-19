tidy_metrics <- function(df) {
  # filter for most recent timestamp
  df <- df |>
    dplyr::filter(session_timestamp == max(session_timestamp))

  # create summary data set with metrics
  sum_df <- df |>
    dplyr::mutate(
      question_time = as.numeric(question_time),
      overall_time = as.numeric(overall_time)
    ) |>
    dplyr::summarize(
      total_time = max(overall_time),
      avg_question_time = mean(question_time),
      total_hints = sum(help_count),
      total_incorrect_attempts = sum(attempts)
    )
  
  return(sum_df)
}