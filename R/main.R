#' @title Main
#' 
#' @importFrom magrittr %>% %<>%
#'
#' @export


main <- function(req, logger = FALSE) {
  
  # Get request content
  allInfo <- req$postBody %>% jsonlite::fromJSON() 
  
  # Append the teamID onto the event!
  allInfo$event$team <- allInfo$team_id
  
  # Block request if necessary
  blockName <- paste0(allInfo$event$channel, allInfo$event$user, allInfo$event_time)

  # Check the request isn't blocked
  result <- blockName %>% 
    req$dbr$GET()

  if (result %>% is.null) {
    # Set a time-out on the particular request (10 minutes)
    blockName %>% req$dbr$SET(
      value = "blocked",
      EX = 60 * 10
    )
    
    # Parse the input & get start and stop stations
    if (logger) cat(crayon::green(" | Parsing message \n"))
    myStations <- allInfo$event %>% 
      translink.bot::parse_message(
        dbr = req$dbr
    )
    
    # If station information exists, report back
    if (myStations$updateAction %>% is.null) {
      startStation <- myStations$startSt
      stopStation <- myStations$stopSt
      
      # Load up station list
      if (logger) cat(crayon::green(" | Getting available stations \n"))
      station.list <- translink.bot::get_stations()
      
      # Lower case everything
      startStation %<>% tolower %>% Hmisc::upFirst()
      stopStation %<>% tolower %>% Hmisc::upFirst()
      
      # Get the start code
      if (logger) cat(crayon::green(" | Checking input against station list \n"))
      startCode <- station.list$code %>% 
        `[`(startStation %>% 
              stringdist::stringdist(station.list$name, method = 'jw') %>%
              which.min
           )
      
      # Get calling information
      if (logger) cat(crayon::green(" | Sending query \n"))
      allresults <- startCode %>% 
        translink.bot::query_live()
      
      # Need to make sure that the start and stop stations are actually close
      # to something at all...
      
      
      # Check the calling points, i.e. get ids in the right direction
      if (logger) cat(crayon::green(" | Parsing calling points \n"))
      correctWay <- lapply(
        X = allresults$callingpoints,
        FUN = function(x) if (stopStation %in% (x %>% `[[`("Name") %>% as.character)) T else F 
      ) %>% 
        purrr::flatten_lgl()
      
      # Subset the right way details
      allresults$callingpoints %<>% `[`(correctWay)
      allresults$myresults %<>% subset(correctWay)
      
      slacktext <- allresults %>% 
        translink.bot::create_text(
          startStation = startStation,
          stopStation = stopStation
        )
      
      mybody <- list(
        token = Sys.getenv("SLACK_TOKEN"), 
        text = slacktext,
        channel = allInfo$event$channel
      )
    } else {
      mybody <- list(
        token = Sys.getenv("SLACK_TOKEN"), 
        text = myStations$updateAction,
        channel = allInfo$event$channel
      )
    }

    # Simple post
    res <- httr::POST(
      url = "https://slack.com/api/chat.postMessage", 
      body = mybody
    )
  }
}
