# An EVM Solidity lottery contract

## Warning: These contracts have not been audited. I am not responsible for any loss of funds or damages incurred.


# How does it work?
### Allows the running of lottery games with `startGame()`, where players acquire tickets with `_token` (ERC20), at `_ticketPrice`, with a total of `_maxPlayers`, playing up to `_maxTicketsPlayer` each. Players can `buyTicket()` at `_numberOfTickets`.

### Player `_token` are transfered to the contract, the winner receives the total accumulation of all player `_token`, in `endGame()`.


## Required tools
`npm install -g solc truffle`

## Local development
`npm install`

## Testing
`truffle test`

