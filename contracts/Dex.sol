// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

//IERC20 interface to manage ERC20 Tokens.
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// Manages the logic of the decentralized exchange.
contract Dex {
    
    /**
      * @notice Owner of the contract for testing and maintenance purposes.
      * @dev Immutable allows to set the value of the state variable once. View constructor.
      */
    address public immutable admin;

    /**
      * @notice Represents a token.
      * @param ticker: short name for the ERC20 Token.
      * @param contractAddress: address of the contract of the ERC20 Token.
      */
    struct Token {
        bytes32 ticker;
        address contractAddress;
    } 

    /**
      * @notice Indicates the side of the order: 'BUY' or 'SELL'.
      */
    enum OrderSide {
        BUY,
        SELL
    }

    /**
      * @notice Basic order in the exchange
      * @param trader: order's creator
      * @param ticker: token to trade in the order
      * @param price: exact price to trade in limit orders
      * @param amount: amount to trade in the order
      * @param side: Buy or Sell
      * @param filled: order's amount filled
      * @param dateOpen: date of creation
    */
    struct Order {
        address trader;
        bytes32 ticker;
        uint256 price;
        uint256 amount;
        OrderSide side;
        uint256 filled;
        uint256 dateOpen;
    }

    /**
      * @notice Relationship of tradable tokens in the exchange indexed by ticker. ticker => Token
      * @dev See state variable 'tickerList'
      */
    mapping(bytes32 => Token) tokenList;

    /**
      * @notice List of all tickers corresponding to accepted tokens
      */
    bytes32[] tickerList;

    /**
      * @notice Relationship of all order books in the exchange, indexed by ticker.
      * @dev  Practically, a mapping of ticker contains 2 mappings corresponding 
      *       to the buy and sell orders.
      *       Order[] batBuyOrders = orderBook['BAT'][OrderSide.BUY];     
      *       Sorting: closest prices between buy and sell are at the begining of the array:
      *        - buy: descending [50, 49, 48]
      *        - Sell: ascending [60, 62, 63]
      *       This sorting makes the matching between buyers and sellers faster.
      */
    mapping(bytes32 => mapping(OrderSide => Order[])) orderBook;

    /**
      * @notice Balances of all traders, indexed by trader address.
      * @dev The external mapping indexes all traders. 
      *      The internal tracks their balance mapping tickers to amounts
      *      balances[msg.address][_ticker]  = amount
      */
    mapping(address => mapping(bytes32 => uint256)) balances;
    
    /**
      * @notice List of traders
      */
    address[] traderList;

    mapping(bytes32 => Token) public tokens;

    /**
      * @notice Contract constructor. 
      *         Runs after deployment and grants admin rights to the deployer.
      */
    constructor() {
        admin = msg.sender;
    }

    /**
      * @notice Returns the list of accepted tickers for tradable tokens on the exchange 
      * @return array of tickers
      */
    function getTickerList() public view returns (bytes32[] memory) {
        return tickerList;
    }

    /**
      * @notice Returns the balance of the specified token for the given address
      * @dev Since internally it's represented with a mapping, it has to be decomposed in 
      *      simpler data types
      * @param _trader Address of the trader
      * @param _ticker Ticker to get the balance of
      * @return uint with the amount of '_ticker' tokens
      */
    function getBalance(address  _trader, bytes32  _ticker) public view returns (uint) {
        return balances[_trader][_ticker];
    }

    function getOrders(bytes32 _ticker, OrderSide _side) external view returns(Order[] memory) {
        return orderBook[_ticker][_side];
    }

      function getTokens() external view returns(Token[] memory) {
          Token[] memory _tokens = new Token[](tickerList.length);
          for (uint i = 0; i < tickerList.length; i++) {
            _tokens[i] = Token(
              tokens[tickerList[i]].ticker,
              tokens[tickerList[i]].contractAddress
            );
          }
          return _tokens;
    }

    /**
      * @notice Adds a new tradable token in the exchange. 
      *         Only the admin address can use this function.
      * @param _ticker Short name of the token
      * @param _contractAddress Address of the token's contract
      */
    function addToken(
        bytes32  _ticker, 
        address  _contractAddress
    ) 
        external 
        onlyAdmin 
        validateAddToken(_ticker) 
        validateAddress(_contractAddress) 
    {
        tickerList.push(_ticker);
        tokenList[_ticker].ticker = _ticker;
        tokenList[_ticker].contractAddress = _contractAddress;
    }

    /**
      * @notice Deletes a tradable token in the exchange. 
      *         Only the admin address can use this function. 
      *         Requires the ticker to exist and not be empty.
      * @param _ticker: short name of the token to be deleted.
      */
    function deleteToken(bytes32  _ticker) external onlyAdmin validateDeleteToken(_ticker) {
      
        delete tokenList[_ticker]; //Logear esto a ver que sale
         
        uint256 i = 0;
        bool found = false;
        while(i<tickerList.length && !found)  {
          if(tickerList[i]==_ticker) {
            delete tickerList[i]; //TODO TEST A VER QUE HACE ESTO - como es la longitud del array despues de borrarlo? Hay que mover todo y hacer un pop()? 
            found = true;
          }
        }
      
    }

    /**
      * @notice Deposits '_amount' of '_ticker' tokens in this contract's address. 
      *         Uses IERC20 Interface to interact with sender's tokens.
      * @param _ticker: short name of the token to deposit
      * @param _amount: amount of token
      */
    function deposit(
        bytes32  _ticker, 
        uint256  _amount
    ) 
        external 
        validateTransferInterface(
            msg.sender, 
            _ticker, 
            _amount
        ) 
    {
        IERC20 token = IERC20(tokenList[_ticker].contractAddress);
        if (token.balanceOf(msg.sender) < _amount) {
          revert invalidAmount(_amount, "Insufficient balance in address");
        } else {
              token.transferFrom(msg.sender, address(this), _amount);
              balances[msg.sender][_ticker] += _amount;
        }
    }

    /**
      * @notice Withdraws '_amount' of '_ticker' tokens to senderś address.
      *         Uses IERC20 Interface to interact with sender's tokens.
      * @param _ticker: short name of the token to deposit
      * @param _amount: amount of token
      */
    function withdraw(
        bytes32  _ticker, 
        uint256  _amount
    ) 
        external 
        validateTransferInterface(msg.sender, _ticker, _amount) 
    {
        if (balances[msg.sender][_ticker] < _amount) {
          revert invalidAmount(_amount, "Address balance insufficient");
        } else {
            IERC20(tokenList[_ticker].contractAddress).transfer(msg.sender, _amount);
            balances[msg.sender][_ticker] -= _amount;
        } 
    }

    /**
      * @notice Validates the input for interface transfer functions deposit() and withdraw().
      * @param _trader: address depositing or withdrawing
      * @param _ticker: short name of the token subject to deposit or withdraw
      * @param _amount: amount of token to be transferred
      */
    modifier validateTransferInterface(address  _trader, bytes32  _ticker, uint256  _amount) {
        if (_trader == address(0))
            revert invalidAddress(_trader, "Trader address is zero");
        else if (_ticker == "")
            revert invalidTicker(_ticker, "ticker is empty");
        else if (_amount == 0)
            revert invalidAmount(_amount, "Amount can't be zero");
        _;
    }

    /**
      * @notice Requires the sender to be the admin of the contract. 
      *         Otherwise will throw a custom error.
      */
    modifier onlyAdmin() {
        if (msg.sender != admin)
            revert accessDenied(msg.sender, "Address unautorithed");
        _;
    }

    /**
      * @notice dev Requires the ticker to not be empty and to exist
      * @param _ticker element to validate
      */
    modifier validateDeleteToken(bytes32  _ticker) {
        if (_ticker == "") 
          revert invalidTicker(_ticker, "ticker is empty");
        else 
          if (tokenList[_ticker].contractAddress == address(0)) 
            revert invalidTicker(_ticker, "token does not exist");
        _;
    }

    /** 
      * @notice Requires the ticker to not be empty and to not be already included
      * @param _ticker element to validate
      */
    modifier validateAddToken(bytes32  _ticker) {
        if (_ticker == "") revert invalidTicker(_ticker, "ticker is empty");
        else 
          if (tokenList[_ticker].contractAddress != address(0)) 
            revert invalidTicker(_ticker, "token already exists");
        _;
    }

    /**
      * @notice Requires the contract address to not be zero and 
      *         to not be have been used for any token of the exchange
      * @param _address element to validate
      */
    modifier validateAddress(address  _address) {
        //Non-zero
        if (_address == 0x0000000000000000000000000000000000000000)
            revert invalidAddress(_address, "Incorrect contract address");

        //Validate if contract address already exists for Token
        uint256 i = 0;
        bool found = false;
        while (i < tickerList.length && !found) {
            if (tokenList[tickerList[i]].contractAddress == _address)
                found = true;
            i++;
        }
        if (found)
            revert invalidAddress(_address, "Contract address already used");
        _;
    }

  /**
    * @notice A trader creates a limit order to buy or sell 
    *         ('_side) '_amount' of '_ticker' token(s) at '_price'.
    *         Requires the trader to have enough balance of USDT (if _side is buy) 
    *         or '_ticker' token (if _side is sell).
    *         TODO: Matches the new order with the existing ones since it's allowed 
    *         to create buy and sell orders at the same * price
    * @param _ticker Short name of the token to trade
    * @param _amount Amount to trade
    * @param _price Limit order price to buy or sell
    * @param _side Buy or sell
    */
  function limitOrder(
      bytes32 _ticker, 
      uint _amount, 
      uint _price, 
      OrderSide _side
  ) 
      external 
      validateLimitOrder(msg.sender, _ticker, _price, _amount,  _side) 
  {
      //Create order and insert order in array
      orderBook[_ticker][_side].push(
        Order(
            msg.sender,
            _ticker,
            _price,
            _amount,
            _side,
            0,
            block.timestamp
        )
      );

      //TODO Match with other side
      //if !filled

      //Array sort
      Order[] storage currentOrderBook = orderBook[_ticker][_side];
      uint  i=currentOrderBook.length;
      bool  completed;
      while(i>0 && !completed) {
          if(_side == OrderSide.BUY) {
              if(currentOrderBook[i-1].price < currentOrderBook[i].price) {
                  swapOrders(currentOrderBook, i-1, i);
                  i--;
              } else completed=true;
          }
          else {
              if(currentOrderBook[i-1].price > currentOrderBook[i].price) {
                  swapOrders(currentOrderBook, i-1, i);
                  i--;
              } else completed=true;
          }
      }
  }

  /**
    * @notice Swaps the content of two positions in an array
    * @param orders Array to swap contents
    * @param index1 First index to swap
    * @param index2 Second idex to swap
    */
  function swapOrders(Order[] storage orders, uint  index1, uint  index2) internal {
        Order storage aux = orders[index2];
        orders[index2] = orders[index1];
        orders[index1] = aux;
    }

   /** 
     * @notice Checks args and USDT trader balance
     * @param _trader Calling address
     * @param _ticker Ticker of the token to trade with
     * @param _price Trigger price of the order
     * @param _amount Amount of tokens to trade with
     * @param _side type of order: buy or sell
     */
   modifier validateLimitOrder(
        address _trader,
        bytes32 _ticker,
        uint256 _price,
        uint256 _amount,
        OrderSide _side
    ) 
    {
        if (_trader == 0x0000000000000000000000000000000000000000)
            revert invalidAddress(_trader, "Invalid trader address");
        else 
            if (_price == 0) 
                revert invalidPrice(_price, "Incorrect price");
            else 
                if (_amount == 0) 
                    revert invalidAmount(_price, "Incorrect Amount");
                else 
                    if(tokenList[_ticker].contractAddress == address(0)) 
                        revert invalidTicker(_ticker, "Ticker does not exist"); //TODO: comprobar que pasa aqui, en realidad lo suyo seria comprobar que tokenList[_ticker].address != address(0) en lugar de esto.
                    else 
                        if(_side == OrderSide.BUY) {
                            //Check USDT balance
                            } else {
                              //Check token balance
                            }
            
            /*
              Pessimistic approach --> There can be a bug in the code and a ticker may exist in tokenList but it doesn't in tickerList.
              Executing this code would add gas cost to the function and, in the event of existing aa bug, would throw an event and also burn all gas
            {
              uint256 i = 0;
              bool found = false;
              while (i < tickerList.length && !found) {
                if (tickerList[i] == _ticker) found = true;
              }
              //trigger evento BUGISMO MAXIMO
              assert(!found, "Contract is bugged!");
            }
            */
        
        _;
    }

    /**
      * @notice Execute a market order. 
      *         Will buy until the '_side' order is filled or all '!_side' orders are filled
      * @dev modifier validates the trader have enough balance of USDT (if _side is buy) or 
      *      '_ticker' token (if _side
      *      is sell).
      * @param _ticker ticker
      * @param _amount amount
      * @param _side  side
      */
    function createMarketOrder(
        bytes32  _ticker,
        uint256  _amount,
        OrderSide  _side
    ) 
        external validateMarketOrder(msg.sender, _ticker, _amount) 
    {
        Order memory mktOrder= Order(msg.sender,_ticker,0,_amount,_side, 0, block.timestamp);
        //Pointer to the order array we want to match 
        //if it's a buy order we match it with sellers and vice versa
        Order[] storage matchOrders = _side==OrderSide.BUY ? orderBook[_ticker][OrderSide.SELL] : orderBook[_ticker][OrderSide.BUY]; 

        uint256 i = 0;
        bool completed = false;
        while (i < matchOrders.length && !completed) {
            //Seller has at least the same amount of tokens than the buyer's amount left to buy.
            if (
                matchOrders[i].amount - matchOrders[i].filled >=  
                mktOrder.amount - mktOrder.filled
                ) {
                    matchOrders[i].filled += matchOrders[i].amount;
                    mktOrder.filled = mktOrder.amount;
                    completed = true;
            } else { 
                //The seller's amount will not satisfy whole buyer's order
                mktOrder.filled = matchOrders[i].amount - matchOrders[i].filled;
                matchOrders[i].filled = matchOrders[i].amount;
                matchOrders.pop();
            }
            i++;
        }
    }

    /**
      * @notice Validates market order arguments
      * @param _trader Caller address
      * @param _ticker Short name of the token to trade
      * @param _amount Qty. of the token to trade
      */
    modifier validateMarketOrder(
        address _trader,
        bytes32 _ticker,
        uint256 _amount
    ) 
    {
        if (_trader == address(0)) {
            revert invalidAddress(_trader, "Invalid trader address");
        } else {
            uint256 i = 0;
            bool found = false;
            while (i < tickerList.length && !found) {
                if (tickerList[i] == _ticker) found = true;
            }
            if (!found) revert invalidTicker(_ticker, "Ticker does not exist");
        }
        _;
    }

    /** 
      * @notice This custom error will be raised usually if an address 
      *         tries to perform an unautorized action on the contract.
      */
    error accessDenied(address, bytes32);

    /** 
      * @notice This custom error will be raised validating "tickers"
      */
    error invalidTicker(bytes32, bytes32);

    /** 
      * @notice This custom error will be raised validating addresses
      */
    error invalidAddress(address, bytes32);

    /** 
      * @notice This custom error will be raised validating prices
      */
    error invalidPrice(uint256, bytes32);

    /** 
      * @notice This custom error will be raised validating amounts of tokens
      */
    error invalidAmount(uint256, bytes32); 
}