//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PredictionMarket {
    constructor() {
        owner = msg.sender;

        //rinkeby network address addded
        priceFeed = AggregatorV3Interface(
            0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
        );
    }

    // DB
    // minimumValue to be deposited
    uint256 public minValueToBeDeposited;

    // owner of the contract
    address public owner;

    //state for bets
    //error handling becomes easier with this
    enum BetType {
        BULL,
        BEAR
    }

    //this makes it easier to reference bets
    enum BetResult {
        WON,
        LOST,
        PENDING
    }

    // struct for txs
    struct Transaction {
        BetType betType;
        uint256 startingValue;
        uint256 endingValue;
        uint256 startingTime;
        uint256 endingTime;
        BetResult betResult;
    }

    // array of all players indicating balances
    // need this to indicate the balance while the bet is ongoing
    mapping(address => uint256) public playerBalances;

    // array of all players indicating history of players
    mapping(address => mapping(uint32 => Transaction))
        public transactionHistory;

    mapping(address => uint32) public numberOfBets;

    AggregatorV3Interface internal priceFeed;

    //MODIFIERS
    //only owner can call a certain function
    modifier _onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // FUNCTIONS
    // deposit for bet
    function depositForBet(BetType _betType) public payable {
        //checking if the money sent is enough
        require(msg.value > minValueToBeDeposited, "is this a joke to you?");

        //update the player's balance
        playerBalances[msg.sender] += msg.value;

        //note the tx in db
        Transaction memory currentTx;
        uint256 startingTimeOfBet = block.timestamp; //using now instead of block.timestamp, the compiler just yelled at me :(
        uint256 endingtimeOfBet = startingTimeOfBet + 2 minutes;

        //getting the starting price of the contract
        uint256 startingPriceForBet = uint256(getLatestPrice());

        //tx object
        currentTx = Transaction(
            _betType,
            startingPriceForBet,
            0,
            startingTimeOfBet,
            endingtimeOfBet,
            BetResult.PENDING
        );

        //updating the db
        transactionHistory[msg.sender][numberOfBets[msg.sender]] = currentTx;

        //add to the total number of bets
        //dunno why but this might be useful in the future
        //why not code it then, you ask?
        //idk, shataap.
        ++numberOfBets[msg.sender]; // smol gas saver, weeeee
    }

    // get value for checking(chainlink)
    function getLatestPrice() public view returns (int256) {
        //latest round data returns a tuple with with multiple values
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return price;
    }

    // withdraw from contract(only owner)

    //get contract's balance back
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    //change min value to be deposited
    function changeMinValueToBeDeposited(uint256 _value) public _onlyOwner {
        minValueToBeDeposited = _value;
    }

    function finalizeBet(uint32 betNumber) public {
        //get the latest/current tx
        Transaction memory txHolder = transactionHistory[msg.sender][betNumber];

        //check if someone's being naughty
        require(
            block.timestamp >= txHolder.endingTime,
            "naughty naughty, you."
        );

        //get the price from chainlink
        uint256 endingPriceForBet = uint256(getLatestPrice());

        //assign ending value to the tx
        txHolder.endingValue = endingPriceForBet;

        //determine with if

        //BULL CASE
        if (txHolder.betType == BetType.BULL) {
            if (txHolder.startingValue <= txHolder.endingValue) {
                //update the db
                txHolder.betResult = BetResult.WON;
            } else {
                //update the db
                txHolder.betResult = BetResult.LOST;
                playerBalances[msg.sender] = 0;
            }
        }

        //BEAR CASE
        if (txHolder.betType == BetType.BEAR) {
            if (txHolder.startingValue >= txHolder.endingValue) {
                //update the db
                txHolder.betResult = BetResult.WON;
            } else {
                //update the db
                txHolder.betResult = BetResult.LOST;
                playerBalances[msg.sender] = 0;
            }
        }

        transactionHistory[msg.sender][betNumber] = txHolder;

        //return a message of some sort
    }
}
