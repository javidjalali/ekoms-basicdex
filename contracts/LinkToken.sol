// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LinkToken is ERC20("Link Token", "LINK") {

    function faucet(uint amount) external {
        _mint(msg.sender, amount);
    }
}   