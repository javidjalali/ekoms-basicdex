// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

//IERC20 interface to manage ERC20 Tokens.
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Manages the logic of the decentralized exchange.
contract Dex {
    
    /**
      * @dev Owner of the contract for testing and maintenance purposes.
      * 
      * Immutable allows to set the value of the state variable once. View constructor.
      */
    address public immutable admin;

    /**
      * @dev Represents a token.
      *   - ticker: short name for the ERC20 Token.
      *   - contractAddress: address of the contract of the ERC20 Token.
      */
    struct Token {
        bytes32 ticker;
        address contractAddress;
    } 

    /**
      * @dev Indicates the side of the order: Buy or Sell.
      */
    enum OrderSide {
        BUY,
        SELL
    }

    /**
      * @dev Basic order in the exchange
      *   - trader: order's creator
      *   - ticker: token to trade in the order
      *   - price: exact price to trade in limit orders
      *   - amount: amount to trade in the order
      *   - side: Buy or Sell
      *   - filled: order's amount filled
      *   - dateOpen: date of creation
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
      * @dev Relationship of tradable tokens in the exchange, indexed by ticker.
      */
    mapping(bytes32 => Token) tokenList;

    /**
      * @dev Relationship of all order books in the exchange, indexed by ticker.
      * Order: closest prices between buy and sell are at the begining of the array:
      *   - buy:  [50, 49, 48]
      *   - Sell: [60, 62, 63]
      * This makes the matching between buyers and sellers faster.
      */
    mapping(bytes32 => mapping(OrderSide => Order[])) orderBook;

    /**
      * @dev List of tradable tokens in the exchange.
      */
    bytes32[] tickerList;

    /**
      * @dev Balances of all traders, indexed by trader address.
      *
      *   - balances[msg.address][_ticker]  = amount
      */
    mapping(address => mapping(bytes32 => uint256)) balances;
    
    /**
      * @dev List of traders
      */
    address[] traderList;

    /**
      * @dev Contract constructor. Runs after deployment and grants admin rights to the deployer.
      */
    constructor() {
        admin = msg.sender;
    }

    /**
      * @dev Returns the list of tradable tokens of the exchange 
      */
    function getTickerList() public view returns (bytes32[] memory) {
      return tickerList;
    }

    /**
      * @dev Returns the balance of the specified token for the given address 
      */
    function getBalance(address  _trader, bytes32  _ticker) public view returns (uint) {
      return balances[_trader][_ticker];
    }

    /**
      * @dev Adds a new tradable token in the exchange. Only the admin address can use this function.
      */
    function addToken(bytes32  _ticker, address  _contractAddress) external onlyAdmin 
      validateAddToken(_ticker) validateAddress(_contractAddress) {
        tickerList.push(_ticker);
        tokenList[_ticker].ticker = _ticker;
        tokenList[_ticker].contractAddress = _contractAddress;
    }

    /**
      * @dev Deletes a tradable token in the exchange. Only the admin address can use this function.
      *
      *   - _ticker: short name of the token to be deleted.
      *
      * Caller must be admin. Requires the ticker to exist and not be empty.
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
      * @dev Deposits '_amount' of '_ticker' tokens in this contract's address. 
      *
      * Uses IERC20 Interface to interact with sender's tokens.
      *
      *   - _ticker: short name of the token to deposit
      *   - _amount: amount of token
      */
    function deposit(bytes32  _ticker, uint256  _amount) external validateTransferInterface(msg.sender, _ticker, _amount) {
        IERC20 token = IERC20(tokenList[_ticker].contractAddress);
        if (token.balanceOf(msg.sender) < _amount) revert invalidAmount(_amount, "Insufficient balance in address");
        else {
          token.transferFrom(msg.sender, address(this), _amount);
          balances[msg.sender][_ticker] += _amount;
        }
    }

    /**
      * @dev Withdraws '_amount' of '_ticker' tokens to senderś address.
      *
      * Uses IERC20 Interface to interact with sender's tokens.
      *
      *   - _ticker: short name of the token to deposit
      *   - _amount: amount of token
      */
    function withdraw(bytes32  _ticker, uint256  _amount) external validateTransferInterface(msg.sender, _ticker, _amount) {
        if (balances[msg.sender][_ticker] < _amount) revert invalidAmount(_amount, "Address balance insufficient");
        else {
            IERC20(tokenList[_ticker].contractAddress).transfer(msg.sender, _amount);
            balances[msg.sender][_ticker] -= _amount;
        } 
    }

    /**
      * @dev Validates the input for interface transfer functions deposit() and withdraw().
      *
      *   - _trader: address depositing or withdrawing
      *   - _ticker: short name of the token subject to depost or withdraw
      *   - _amount: amount of token to be transferred
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
      * @dev Requires the sender to be the admin of the contract. Otherwise will throw a custom error.
      */
    modifier onlyAdmin() {
        if (msg.sender != admin)
            revert accessDenied(msg.sender, "Address unautorithed");
        _;
    }

    /**
      * @dev Requires the ticker to not be empty and to exist
      */
    modifier validateDeleteToken(bytes32  _ticker) {
        if (_ticker == "") revert invalidTicker(_ticker, "ticker is empty");
        else if (tokenList[_ticker].contractAddress == address(0)) revert invalidTicker(_ticker, "token does not exist");
        _;
    }

    /** 
      * @dev Requires the ticker to not be empty and to not be already included
      */
    modifier validateAddToken(bytes32  _ticker) {
        if (_ticker == "") revert invalidTicker(_ticker, "ticker is empty");
        else if (tokenList[_ticker].contractAddress != address(0)) revert invalidTicker(_ticker, "token already exists");
        _;
    }

    /**
      * @dev Requires the contract address to not be zero and to not be have been used for any token of the exchange
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
    * @dev A trader creates a limit order to buy or sell ('_side) '_amount' of '_ticker' token(s) at '_price'.
    * 
    * Requires the trader to have enough balance of USDT (if _side is buy) or '_ticker' token (if _side is sell).
    * 
    * TODO: Matches the new order with the existing ones since it's allowed to create buy and sell orders at the same * price
    */
  function limitOrder(bytes32 _ticker, uint _amount, uint _price, OrderSide _side) external validateLimitOrder(msg.sender, _ticker, _price, _amount,  _side) {
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

        //Match with other side
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
                }
                else completed=true;
            }
            else {
                if(currentOrderBook[i-1].price > currentOrderBook[i].price) {
                    swapOrders(currentOrderBook, i-1, i);
                    i--;
                 }
                 else completed=true;
            }
         }
  }

    function swapOrders(Order[] storage orders, uint  index1, uint  index2) internal {
        Order storage aux = orders[index2];
        orders[index2] = orders[index1];
        orders[index1] = aux;
    }

   /** 
     * @dev Checks args and USDT trader balance
     */
   modifier validateLimitOrder(
        address _trader,
        bytes32 _ticker,
        uint256 _price,
        uint256 _amount,
        OrderSide _side
    ) {
        if (_trader == 0x0000000000000000000000000000000000000000)
            revert invalidAddress(_trader, "Invalid trader address");
        else if (_price == 0) revert invalidPrice(_price, "Incorrect price");
        else if (_amount == 0) revert invalidAmount(_price, "Incorrect Amount");
        else if(tokenList[_ticker].contractAddress == address(0)) revert invalidTicker(_ticker, "Ticker does not exist"); //TODO: comprobar que pasa aqui, en realidad lo suyo seria comprobar que tokenList[_ticker].address != address(0) en lugar de esto.
        else if(_side == OrderSide.BUY) {
          //Check USDT balance
        }
        else {
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
      * @notice Execute a market order. Will buy until the '_side' order is filled or all '!_side' orders are filled
      * 
      * @dev modifier validates the trader have enough balance of USDT (if _side is buy) or '_ticker' token (if _side
      *      is sell).
      * @param _ticker ticker
      * @param _amount amount
      * @param _side  side
      */
    function createMarketOrder(
        bytes32  _ticker,
        uint256  _amount,
        OrderSide  _side
    ) external validateMarketOrderArgs(msg.sender, _ticker, _amount) {



 

        Order memory mktOrder= Order(msg.sender,_ticker,0,_amount,_side, 0, block.timestamp);

        //Pointer to the order array we want to match -> if itś a buy order we match it with sellers and vice versa
        Order[] storage matchOrders = _side==OrderSide.BUY ? orderBook[_ticker][OrderSide.SELL] : orderBook[_ticker][OrderSide.BUY]; 

        uint256 i = 0;
        bool completed = false;
        while (i < matchOrders.length && !completed) {
            //Seller has at least the same amount of tokens than the buyer's amount left to buy.
            if (matchOrders[i].amount - matchOrders[i].filled >=  mktOrder.amount - mktOrder.filled) {
                matchOrders[i].filled += matchOrders[i].amount;
                mktOrder.filled = mktOrder.amount;
                completed = true;
            }
            //The seller's amount will not satisfy whole buyer's order
            else {
                mktOrder.filled = matchOrders[i].amount - matchOrders[i].filled;
                matchOrders[i].filled = matchOrders[i].amount;
                matchOrders.pop();
            }
            i++;
        }


    }


    /**
      * @dev Orders the last item of the BUY side of an orderbook. 
      * 
      * Buyers follows descending order 
      
    function orderBuyers(Order[] storage buyOrders) internal {
        int256 i = buyOrders.length - 1;
        bool completed = false;
        while (i >= 0 && !completed) {
            if (i > 0) {
                // Previous element is lower than current (new) => Swap elements
                if (buyOrders[i - 1].price < buyOrders[i].price) {
                    Order storage aux = buyOrders[i - 1];
                    buyOrders[i - 1] = buyOrders[i];
                    buyOrders[i] = aux;
                }
                // Previous element is greater or equal => finish ordering
                else completed = true;
            }
            //Reaches first element
            else completed = true;
            i--;
        }
    }
*/
    /**
      * @dev Orders the last item of the SELL side of an orderbook.  
      * 
      * Sellers follows ascending order 
      
    function orderSellers(Order[] storage sellOrders) internal {
        uint256 i = sellOrders.length - 1;
        bool completed = false;
        while (i >= 0 && !completed) {
            if (i > 0) {
               // Previous element is lower than current (new) => Swap elements
                if (sellOrders[i - 1].price < sellOrders[i].price) {
                    Order aux = sellOrders[i];
                    sellOrders[i-1] = sellOrders[i];
                    sellOrders[i] = aux;
               }
               // Previous element is lower than current (new) => Finish ordering
               else completed = true;
            } 
            //Reaches first element 
            else completed = true;
            i--;
        }
    }
*/
 

    modifier validateMarketOrderArgs(
        address _trader,
        bytes32 _ticker,
        uint256 _amount
    ) {
        if (_trader == 0x0000000000000000000000000000000000000000)
            revert invalidAddress(_trader, "Invalid trader address");
        else {
            uint256 i = 0;
            bool found = false;
            while (i < tickerList.length && !found) {
                if (tickerList[i] == _ticker) found = true;
            }
            if (!found) revert invalidTicker(_ticker, "Ticker does not exist");
        }
        _;
    }

    // This custom error will be raised if an address tries to perform an unautorithez action on the contract.
    error accessDenied(address, bytes32);

    // This custom error will be raised validating "tickers"
    error invalidTicker(bytes32, bytes32);

    // This custom error will be raised validating addresses
    error invalidAddress(address, bytes32);

    // This custom error will be raised validating prices
    error invalidPrice(uint256, bytes32);

    // This custom error will be raised validating amounts of tokens
    error invalidAmount(uint256, bytes32);
}


  /*
    function createLimitOrder(bytes32  _ticker, uint256  _price,uint256  _amount, OrderSide  _side) external 
        validateLimitOrderArgs(msg.sender, _ticker, _price, _amount) {
          if (_side == OrderSide.BUY) {
            orderBook[_ticker].buyers.push(
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
            limitMatchWithSellers(
                orderBook[_ticker].buyers[orderBook[_ticker].buyers.length - 1],
                orderBook[_ticker].sellers
            );
            orderBuyers(orderBook[_ticker].buyers);
        } else if (_side == OrderSide.SELL) {
            orderBook[_ticker].sellers.push(
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
            limitMatchWithBuyers(
                orderBook[_ticker].sellers[
                    orderBook[_ticker].sellers.length - 1
                ],
                orderBook[_ticker].buyers
            );
            orderSellers(orderBook[_ticker].sellers);
        }
    }

    function limitMatchWithSellers(
        Order storage _buyer,
        Order[] storage _sellers
    ) internal {
        uint256 i = _sellers.length - 1;
        bool completed = false;
        while (i >= 0 && !completed) {
            if (_sellers[i].price == _buyer.price) {
                //Seller has at least the same amount of tokens than the buyer's amount left to buy.
                if (
                    _sellers[i].amount - _sellers[i].filled >=
                    _buyer.amount - _buyer.filled
                ) {
                    _sellers[i].filled += _buyer.amount; //if _sellers[i].filled=_sellers[i].amount delete _sellers[i]?
                    _buyer.filled = _buyer.amount; //delete _buyer?

                    //TODO: SEND TRANSACTION TO BUYER/BOTH?

                    completed = true;
                }
                //The seller's amount will not satisfy whole buyer's order
                else {
                    _buyer.filled = _sellers[i].amount - _sellers[i].filled;
                    _sellers[i].filled = _sellers[i].amount; //delete seller?

                    //TODO: SEND TRANSACTION TO SELLER?
                }
            }

            i--;
        }
        // if(_buyer.filled = _buyer.amount) cargarselo?
        // if(_buyer.filled = _buyer.amount) cargarselo?
    }

    function limitMatchWithBuyers(
        Order storage _seller,
        Order[] storage _buyers
    ) internal {
        uint256 i = _buyers.length - 1;
        bool completed = false;
        while (i >= 0 && !completed) {
            if (_buyers[i].price == _seller.price) {
                //buyer has at least the same amount of tokens than the sellers's amount left to sell.
                if (
                    _buyers[i].amount - _buyers[i].filled >=
                    _seller.amount - _seller.filled
                ) {
                    _buyers[i].filled += _seller.amount; //if _sellers[i].filled=_sellers[i].amount delete _sellers[i]?
                    _seller.filled = _seller.amount; //delete _buyer?
                    //SEND TRANSACTION TO BUYER/BOTH?
                    completed = true;
                }
                //The seller's amount will not satisfy whole buyer's order
                else {
                    _seller.filled = _buyers[i].amount - _buyers[i].filled;
                    _buyers[i].filled = _buyers[i].amount; //delete seller?
                    //SEND TRANSACTION TO SELLER?
                }
            }
            i--;
        }
        // if(_buyer.filled = _buyer.amount) cargarselo?
        // if(_buyer.filled = _buyer.amount) cargarselo?
    }
*/