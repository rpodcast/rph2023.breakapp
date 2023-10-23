tidy_metrics <- function(df) {
  # filter for most recent timestamp
  df <- df |>
    dplyr::filter(session_timestamp == max(session_timestamp))

  # check for users that only started the game without
  # any attempts to answer
  if (all(df$event_type == "start_session")) {
    sum_df <- tibble::tibble(
      total_time = df$overall_time,
      total_correct = 0,
      avg_question_time = NA,
      total_hints = 0,
      total_incorrect_attempts = 0
    )
  } else {
    # compute variables individually
    total_time <- df |>
      dplyr::filter(event_type != "start_session") |>
      dplyr::slice_max(overall_time, with_ties = FALSE) |>
      dplyr::pull(overall_time)
    
    total_correct <- sum(df$correct_answer_ind)

    avg_question_time <- df |>
      dplyr::filter(event_type == "submit_answer") |>
      dplyr::filter(correct_answer_ind) |>
      dplyr::pull(question_time) |>
      mean()

    total_hints <- df |>
      dplyr::filter(event_type == "request_hint") |>
      dplyr::group_by(question_id) |>
      dplyr::slice_max(hint_counter, with_ties = FALSE) |>
      #dplyr::filter(hint_counter == max(hint_counter)) |>
      dplyr::pull(hint_counter) |>
      sum()

    total_incorrect_attempts <- df |>
      dplyr::filter(event_type == "submit_answer") |>
      dplyr::filter(!correct_answer_ind) |>
      dplyr::group_by(question_id) |>
      dplyr::slice_max(attempt_counter, with_ties = FALSE) |>
      #dplyr::filter(attempt_counter == max(attempt_counter)) |>
      dplyr::pull(attempt_counter) |>
      sum()

    sum_df <- tibble::tibble(
      total_time = total_time,
      total_correct = total_correct,
      avg_question_time = avg_question_time,
      total_hints = total_hints,
      total_incorrect_attempts = total_incorrect_attempts
    )
  }

  return(sum_df)
}