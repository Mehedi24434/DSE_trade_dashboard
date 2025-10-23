library(rvest)
library(dplyr)
library(readr)
library(lubridate)
library(stringr)

scrap_data_updater <- function(last_day) {
  # URL for archived data
  url <- paste0(
    "https://www.dsebd.org/day_end_archive.php?startDate=",
    last_day, "&endDate=", last_day, "&inst=All%20Instrument&archive=data"
  )
  
  # Read tables from the page
  tables <- read_html(url) %>% html_table(fill = TRUE)
  ohlcv_table <- tables[[length(tables) - 1]]   # equivalent of df_list[-2]
  
  # Rename columns to match your Python code
  ohlcv_table <- ohlcv_table %>%
    rename(
      Scrip = `TRADING CODE`,
      High = HIGH,
      Low = LOW,
      Close = `CLOSEP*`,
      Open = `OPENP*`,
      Volume = VOLUME,
      Trade = TRADE
    ) %>%
    mutate(Date = last_day) %>%
    # Convert numeric columns safely
    mutate(
      Open = as.numeric(str_replace_all(Open, ",", "")),
      High = as.numeric(str_replace_all(High, ",", "")),
      Low = as.numeric(str_replace_all(Low, ",", "")),
      Close = as.numeric(str_replace_all(Close, ",", "")),
      Volume = as.numeric(str_replace_all(Volume, ",", "")),
      Trade = as.numeric(str_replace_all(Trade, ",", ""))
    )
  
  folder_path <- "./Scrapped_data/daily"
  
  ticker_list <- ohlcv_table$Scrip %>% unique() %>% setdiff(c("No Day End Data", "", NA))
  csv_files <- list.files(folder_path, pattern = "\\.csv$") %>% str_remove("\\.csv$")
  no_update_tickers <- setdiff(csv_files, ticker_list)
  
  # Update existing tickers
  for(ticker_name in ticker_list) {
    ticker_file <- file.path(folder_path, paste0(ticker_name, ".csv"))
    if(file.exists(ticker_file)) {
      ticker_data <- read_csv(ticker_file, show_col_types = FALSE)
      new_row <- ohlcv_table %>% filter(Scrip == ticker_name) %>%
        select(Date, Open, High, Low, Close, Volume, Trade) %>%
        rename(
          date = Date, open = Open, high = High, low = Low,
          close = Close, volume = Volume, trade = Trade
        )
      ticker_data <- bind_rows(ticker_data, new_row)
      write_csv(ticker_data, ticker_file)
      cat("Done for", ticker_name, "\n")
    } else {
      cat("Ticker file not found for", ticker_name, "\n")
    }
  }
  
  # Update non-traded tickers with previous close
  writtable_tickers <- c()
  for(ticker_name in no_update_tickers){
  ticker_file <- file.path(folder_path, paste0(ticker_name, ".csv"))
  
  if(file.exists(ticker_file)){
    ticker_data <- read_csv(ticker_file, show_col_types = FALSE)
    
    # --- Convert the last row date safely ---
    last_date <- ymd(ticker_data$date[nrow(ticker_data)])  # safely parse last date
last_day_date <- ymd(last_day)                         # parse last_day

d <- as.numeric(last_day_date - last_date)

if(!is.na(d) && d < 7){   # check for NA before comparison
  writtable_tickers <- c(writtable_tickers, ticker_name)
}

  }
}
  
  for(ticker_name in writtable_tickers) {
    ticker_file <- file.path(folder_path, paste0(ticker_name, ".csv"))
    ticker_data <- read_csv(ticker_file, show_col_types = FALSE)
    last_close <- ticker_data$close[nrow(ticker_data)]
    new_row <- tibble(
      date = last_day,
      open = last_close,
      high = last_close,
      low = last_close,
      close = last_close,
      volume = 0,
      trade = 0
    )
    ticker_data <- bind_rows(ticker_data, new_row)
    write_csv(ticker_data, ticker_file)
    cat("Filled previous close for", ticker_name, "\n")
  }
}

replace_zero_with_close <- function(folder_path) {
  files <- list.files(folder_path, pattern = "\\.csv$", full.names = TRUE)
  for(file in files) {
    df <- read_csv(file, show_col_types = FALSE)
    if(all(c("open","high","low","close") %in% names(df))) {
      df <- df %>%
        mutate(
          open = ifelse(open == 0, close, open),
          high = ifelse(high == 0, close, high),
          low = ifelse(low == 0, close, low)
        )
      write_csv(df, file)
      cat("Updated:", basename(file), "\n")
    }
  }
}