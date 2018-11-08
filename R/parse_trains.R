#' @title Parse Trains
#' 
#' @export


parse_trains <- function(event) {
  
  # Get the actual message
  myMessage <- event$text

  # Make sure to statement exists
  if ("to" %in% myMessage) {
  
    # Get to index
    myInd <- "to" %>% 
      `==`(myMessage) %>%
      which
    
    # Parse out stations
    startSt <- myMessage[1:(myInd %>% `-`(1))]
    stopSt <- myMessage[(myInd %>% `+`(1)):(myMessage %>% length)]

    # Get station list
    station.list <- translink.bot::get_stations()

    # Upper-case first character
    startSt %<>% translink.bot::format_name()
    stopSt %<>% translink.bot::format_name()

    # Get the start code
    startCode <- station.list$code %>% 
      `[`(startSt %>% 
            stringdist::stringdist(station.list$name, method = 'jw') %>%
            which.min
      )
    
    # Get calling information
    allresults <- startCode %>% 
      translink.bot::query_live()
    
    correctWay <- lapply(
      X = allresults$callingpoints,
      FUN = function(x) if (stopSt %in% (x %>% `[[`("Name") %>% as.character)) T else F 
    ) %>% 
      purrr::flatten_lgl()
    
    # Subset the right way details
    allresults$callingpoints %<>% `[`(correctWay)
    allresults$myresults %<>% subset(correctWay)
    
    slackTxt <- allresults %>% 
      translink.bot::create_text(
        startStation = startSt,
        stopStation = stopSt
      )
  } else {
    slackTxt <- "Could not find `to` tag..."
  }
  
  # Return text for slack
  return(slackTxt)
}