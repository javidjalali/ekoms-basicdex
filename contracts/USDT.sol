// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "playground/EatTheBlocks/Dex/node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is IERC20("Billetes de monopoly", "USDT") {

    function faucet(uint amount) external {
        _mint(msg.sender, amount);
    }
}   