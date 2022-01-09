// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20("Billetes de monopoly", "USDT") {

    function faucet(uint amount) external {
        _mint(msg.sender, amount);
    }
}   