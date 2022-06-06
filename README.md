# Blockchain raffle (Solidity EVM contracts)

## Warning: These contracts have not been audited. I am not responsible for any loss of funds or damages incurred.


# How does it work?
### Allows the running of lottery games with `startGame()`, where players acquire tickets with `gameToken` (ERC20), at `gameTicketPrice`, with a total of `gameMaxPlayers`, playing up to `gameMaxTicketsPlayer` each. Players can `buyTicket()` at `_numberOfTickets`.

### Player's `gameToken` are transfered to the contract, the winner receives the total `_pot` of all player `gameToken` on contract, and any additional game pots defined with `addGamePotERC20Asset()` or `addGamePotERC721Asset()`, in `endGame()`. Minus `gameFeePercent` (hundredth) fee to `gameFeeAddress`.


## Required tools
`npm install -g solc truffle`

## Local development
`npm install`

## Testing
`truffle test`

## A Next.js front-end
https://github.com/AlexanderGW/raffle-nextjs