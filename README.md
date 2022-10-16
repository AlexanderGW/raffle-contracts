# Blockchain raffle (Solidity EVM contracts)

## Warning: These contracts have not been audited. I am not responsible for any loss of funds or damages incurred.


# How does it work?
### Allows the running of lottery games with `startGame()`, where players acquire tickets with `gameToken` (ERC20), at `gameTicketPrice`, with a total of `gameMaxPlayers`, playing up to `gameMaxTicketsPlayer` each. Players can `buyTicket()` at `_numberOfTickets`.

### Player's `gameToken` are transfered to the contract, the winner receives the total `_pot` of all player `gameToken` on contract, and any additional game pots defined with `addGamePotERC20Asset()`, `addGamePotERC721Asset()` or `addGamePotERC1155Asset()`, in `endGame()`. Minus `gameFeePercent` (hundredth) fee to `gameFeeAddress`.

#### Caveat
Ideally needs a keeper bot to make frequent irregular calls of `Oracle.feedRandomness(uint256)`, to make it difficult to determine game outcomes.


## Requirements
### Tools
`npm install -g solc truffle`

### Configuration
Truffle `optimizer` **MUST** be `true`, in order to compile these contracts. Use a low `run` value, to compile faster in testing scenarios.


## Local development
`npm install`

## Testing
`truffle test`

## A Next.js front-end
https://github.com/AlexanderGW/raffle-nextjs