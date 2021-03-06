#' @title Parse Delete Favourites
#' 
#' @export


parse_delete <- function(dbr, event) {
  
  myMessage <- event$text

  # Look up ALL favourites
  allFavs <- paste0(event$team_id, ":", event$user_id, "*") %>% 
    dbr$KEYS()
  
  # Flatten list of favourites
  if (allFavs %>% length %>% `>`(0)) {
    allFavs %<>% purrr::flatten_chr()
    
    # Set up pipeline
    redpipe <- redux::redis
    
    # Get all keywords
    allkwords <- allFavs %>% 
      strsplit(split = ":") %>% 
      purrr::map(3) %>% 
      purrr::flatten_chr()
    
    # Get all keywords
    kwords <- myMessage
    
    # Check intersection
    multikw <- kwords %>% intersect(allkwords)
    
    if ("all" %in% kwords) {
      results <- dbr$pipeline(
        .commands = lapply(
          X = allFavs,
          FUN = function(x) x %>% redpipe$DEL()
        )
      ) %>%
        purrr::flatten_chr()
      
      favnames <- allkwords
    } else if (multikw %>% length %>% `>`(0)) {
      # Which one? match them up first
      results <- dbr$pipeline(
        .commands = lapply(
          X = allFavs[multikw %>% match(allkwords)],
          FUN = function(x) x %>% redpipe$DEL()
        )
      ) %>%
        purrr::flatten_chr()
      
      favnames <- multikw
    } else {
      return(paste0("Nothing to delete for the supplied arguments"))
    }
    
    slackTxt <- paste0("Deleting routes: \n- ", favnames %>% paste(collapse = "\n- "))
  } else {
    slackTxt <- "You do not have any routes to delete"
  }
  
  # Return string back to slack
  return(slackTxt)
}