# CUSTOM ALIASES START
alias shopdev='docker exec -it shopify-cli bash -c "cd YOUR_PROJECT_DIRECTORY && shopify theme dev --store YOUR_STORE_NAME"'
# CUSTOM ALIASES END

# CUSTOM FUNCTIONS START
shopush() {
  local theme_id=$1
  docker exec -it shopify-cli bash -c "cd YOUR_PROJECT_DIRECTORY && shopify theme push -t $theme_id"
}
shopull() {
  local theme_id=$1
  docker exec -it shopify-cli bash -c "cd YOUR_PROJECT_DIRECTORY && shopify theme pull -t $theme_id"
}
# CUSTOM FUNCTIONS END